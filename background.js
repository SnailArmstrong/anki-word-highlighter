// background.js - Background Sync Service Worker for AnkiSpanishSync

const DB_NAME = 'AnkiSpanishSyncDB';
const STORE_NAME = 'dictionary';

// --- IndexedDB Helper ---
function openDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = (e) => {
      const db = e.target.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME);
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function getIDB(key) {
  try {
    const db = await openDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const req = tx.objectStore(STORE_NAME).get(key);
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  } catch (err) {
    console.error('IndexedDB read error:', err);
    return null;
  }
}

// --- Direct AnkiConnect Invocation with IPv4/IPv6 Fallback ---
async function invoke(action, params = {}) {
  const endpoints = ['http://localhost:8765', 'http://127.0.0.1:8765'];
  let lastError;

  for (const url of endpoints) {
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action, version: 6, params })
      });
      if (res.ok) {
        return await res.json();
      }
    } catch (err) {
      lastError = err;
    }
  }
  throw new Error(`AnkiConnect connection failed: ${lastError?.message || 'Network unreachable'}`);
}

// --- Helper: Extract & Clean Individual Spanish Words from Anki Field ---
function extractSpanishWords(rawFieldText) {
  if (!rawFieldText) return [];
  
  let text = String(rawFieldText).normalize('NFC');
  text = text.replace(/\[[^\]]*\]/g, ''); 
  text = text.replace(/<[^>]*>/g, ''); 
  text = text.replace(/&nbsp;/gi, ' '); 
  text = text.replace(/[\u200B-\u200D\uFEFF]/g, ''); 
  text = text.replace(/\([^)]*\)/g, ' '); 

  const rawTokens = text.split(/[/,;\n\r]+/);
  const results = [];

  rawTokens.forEach(token => {
    let clean = token.toLowerCase().trim();
    clean = clean.replace(/^(el|la|los|las|un|una|unos|unas)\s+/i, '');

    // Fixed expressions / phrasal entries (e.g. "tener miedo") have internal
    // spaces. Clean each word separately instead of the whole phrase, or the
    // space would get stripped along with punctuation and produce one
    // run-on string ("tenermiedo") that can never match page text.
    clean.split(/\s+/).forEach(word => {
      const cleanWord = word.replace(/[^\p{L}\p{M}\p{N}_]/gu, '');
      if (cleanWord.length > 1) {
        results.push(cleanWord);
      }
    });
  });

  return results;
}

// --- Reflexive Verb Variant Generator ---
function getWordVariants(word) {
  const clean = word.normalize('NFC').toLowerCase().trim();
  const variants = new Set([clean]);
  
  if (clean.endsWith('se') && clean.length > 4) {
    variants.add(clean.slice(0, -2));
  } else if (clean.endsWith('ar') || clean.endsWith('er') || clean.endsWith('ir')) {
    variants.add(clean + 'se');
  }
  return Array.from(variants);
}

// --- Notify Open Tabs on Settings / Word Updates ---
async function notifyTabsOfUpdate() {
  try {
    const tabs = await chrome.tabs.query({});
    for (const tab of tabs) {
      if (tab.id) {
        chrome.tabs.sendMessage(tab.id, { action: 'SETTINGS_UPDATED' }).catch(() => {});
      }
    }
  } catch (err) {
    console.warn('Could not broadcast SETTINGS_UPDATED to tabs:', err);
  }
}

// --- Mature/Suspended Note Lookup ---
// Looks up interval-graduated notes and suspended notes as two separate,
// independently-guarded queries (rather than one combined boolean query)
// because AnkiConnect Android is a community reimplementation of the API and its
// search parser may not support the same syntax as desktop AnkiConnect -- if one
// operator isn't supported there, the other should still work rather than the
// whole sync failing.
async function getIntervalAndSuspensionData(safeDeck) {
  const matureIds = new Set();
  const suspendedIds = new Set();

  try {
    const matureRes = await invoke('findNotes', { query: `deck:"${safeDeck}" prop:ivl>=21` });
    if (matureRes.error) {
      console.warn(`Mature-interval lookup failed: ${matureRes.error}`);
    } else {
      (matureRes.result || []).forEach(id => matureIds.add(String(id)));
    }
  } catch (err) {
    console.warn(`Mature-interval lookup failed: ${err.message}`);
  }

  try {
    const suspendedRes = await invoke('findNotes', { query: `deck:"${safeDeck}" is:suspended` });
    if (suspendedRes.error) {
      console.warn(`Suspended-card lookup failed: ${suspendedRes.error}`);
    } else {
      (suspendedRes.result || []).forEach(id => suspendedIds.add(String(id)));
    }
  } catch (err) {
    console.warn(`Suspended-card lookup failed (your AnkiConnect server may not support "is:suspended"): ${err.message}`);
  }

  return { matureIds, suspendedIds };
}

// --- Main Sync Engine ---
async function syncAnkiWords(targetDeck = 'Mined word', targetField = 'Spanish Word') {
  const safeDeck = targetDeck.replace(/"/g, '\\"');

  const findNotesRes = await invoke('findNotes', { query: `deck:"${safeDeck}"` });
  if (findNotesRes.error) throw new Error(`AnkiConnect Error: ${findNotesRes.error}`);
  
  const noteIds = findNotesRes.result;
  if (!noteIds || noteIds.length === 0) {
    await chrome.storage.local.set({ spanishWords: {} });
    await notifyTabsOfUpdate();
    return 0;
  }

  const chunkSize = 50;
  let allNotes = [];

  for (let i = 0; i < noteIds.length; i += chunkSize) {
    const chunk = noteIds.slice(i, i + chunkSize);
    const notesInfoRes = await invoke('notesInfo', { notes: chunk });
    if (notesInfoRes.error) throw new Error(`AnkiConnect Error: ${notesInfoRes.error}`);
    if (notesInfoRes.result) allNotes = allNotes.concat(notesInfoRes.result);
  }

  const { matureIds, suspendedIds } = await getIntervalAndSuspensionData(safeDeck);

  const {
    suspendedOverrideEnabled = false,
    suspendedOverrideStatus = 'mature'
  } = await chrome.storage.local.get(['suspendedOverrideEnabled', 'suspendedOverrideStatus']);

  const wordCache = {};
  const rootWordsMap = {};

  allNotes.forEach(note => {
    if (note.fields && note.fields[targetField] && note.fields[targetField].value) {
      const noteIdStr = String(note.noteId);
      const isNoteSuspended = suspendedIds.has(noteIdStr);

      let currentStatus;
      if (suspendedOverrideEnabled && isNoteSuspended) {
        // User has opted to override suspended cards' status regardless of interval.
        if (suspendedOverrideStatus === 'ignore') {
          return; // Skip this note entirely -- its words won't be highlighted
                  // unless a different, non-suspended note also contains them.
        }
        currentStatus = suspendedOverrideStatus === 'learning' ? 'learning' : 'mature';
      } else {
        const isNoteMature = matureIds.has(noteIdStr);
        currentStatus = isNoteMature ? 'mature' : 'learning';
      }

      const extractedWords = extractSpanishWords(note.fields[targetField].value);

      extractedWords.forEach(baseWord => {
        const variants = getWordVariants(baseWord);
        variants.forEach(variant => {
          if (!wordCache[variant] || currentStatus === 'mature') {
            rootWordsMap[variant] = currentStatus;
            wordCache[variant] = currentStatus;
          }
        });
      });
    }
  });

  const lemmatizationRules = (await getIDB('lemmatizationRules')) || {};

  Object.entries(lemmatizationRules).forEach(([inflectedForm, rootLemmas]) => {
    const cleanInflection = inflectedForm.normalize('NFC').toLowerCase().trim();
    const roots = Array.isArray(rootLemmas) ? rootLemmas : [rootLemmas];

    roots.forEach(rootLemma => {
      const cleanRoot = String(rootLemma).normalize('NFC').toLowerCase().trim();

      if (rootWordsMap[cleanRoot]) {
        const sharedStatus = rootWordsMap[cleanRoot];

        if (wordCache[cleanInflection]) {
          if (sharedStatus === 'mature') {
            wordCache[cleanInflection] = 'mature';
          }
        } else {
          wordCache[cleanInflection] = sharedStatus;
        }
      }
    });
  });

  await chrome.storage.local.set({ spanishWords: wordCache });
  await notifyTabsOfUpdate();

  return Object.keys(wordCache).length;
}

// --- Global Message Listener ---
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'FORCE_SYNC') {
    chrome.storage.local.get(['selectedDeck', 'selectedField'], (data) => {
      const deck = data.selectedDeck || 'Mined word';
      const field = data.selectedField || 'Spanish Word';
      
      syncAnkiWords(deck, field)
        .then(count => sendResponse({ success: true, count }))
        .catch(err => {
          console.error(err);
          sendResponse({ success: false, error: err.message });
        });
    });
    return true;
  }

  if (message.action === 'GET_DECKS') {
    invoke('deckNames')
      .then(res => sendResponse({ success: !res.error, data: res.result, error: res.error }))
      .catch(err => sendResponse({ success: false, error: err.message }));
    return true;
  }

  if (message.action === 'GET_FIELDS_FOR_DECK') {
    const safeDeck = (message.deck || '').replace(/"/g, '\\"');
    invoke('findNotes', { query: `deck:"${safeDeck}"` })
      .then(res => {
        if (!res.result || res.result.length === 0) return { result: [] }; 
        const firstNoteId = res.result[0]; 
        return invoke('notesInfo', { notes: [firstNoteId] });
      })
      .then(res => {
        if (res && res.result && res.result.length > 0) {
          const firstNote = res.result[0]; 
          const keys = Object.keys(firstNote.fields || {});
          sendResponse({ success: true, data: keys });
        } else {
          sendResponse({ success: true, data: [] });
        }
      })
      .catch(err => {
        console.error(err);
        sendResponse({ success: false, error: err.message });
      });
    return true; 
  }
}); 

// Initial sync trigger when background service worker wakes up
chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.local.get(['selectedDeck', 'selectedField'], (data) => {
    syncAnkiWords(data.selectedDeck || 'Mined word', data.selectedField || 'Spanish Word')
      .catch(err => console.warn('Initial background sync deferred:', err.message));
  });
});