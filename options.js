// options.js - Full Controller for options.html

const DB_NAME = 'AnkiSpanishSyncDB';
const STORE_NAME = 'dictionary';

// --- UI Status Helpers ---
function showStatus(text, type = 'info') {
  const statusEl = document.getElementById('status');
  if (!statusEl) return;
  statusEl.textContent = text;
  statusEl.className = `status-msg ${type}`;
}

async function updateStatsInfo() {
  const statsEl = document.getElementById('statsInfo');
  if (!statsEl) return;
  const { spanishWords = {} } = await chrome.storage.local.get('spanishWords');
  const count = Object.keys(spanishWords).length;
  statsEl.textContent = count > 0 ? `Active Dictionary: ${count} cached terms` : 'No active words cached';
}

// --- IndexedDB Helpers ---
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

async function putIDB(key, value) {
  try {
    const db = await openDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const req = store.put(value, key);
      req.onsuccess = () => resolve();
      req.onerror = () => reject(req.error);
    });
  } catch (err) {
    console.error('IndexedDB write error:', err);
    throw err;
  }
}

async function clearIDB() {
  try {
    const db = await openDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const req = store.clear();
      req.onsuccess = () => resolve();
      req.onerror = () => reject(req.error);
    });
  } catch (err) {
    console.error('IndexedDB clear error:', err);
  }
}

// --- Lemmatization & Definition Parser Helpers ---
function addRootAndReflexiveVariants(word, targetSet) {
  if (!word || typeof word !== 'string') return;
  const clean = word.normalize('NFC').toLowerCase().trim();
  if (clean.length <= 1) return;
  targetSet.add(clean);

  if (clean.endsWith('se') && clean.length > 4) {
    targetSet.add(clean.slice(0, -2));
  } else if (clean.endsWith('ar') || clean.endsWith('er') || clean.endsWith('ir')) {
    targetSet.add(clean + 'se');
  }
}

/**
 * Robust definition parser with Unicode NFC normalization and global lemma extraction.
 */
function extractLemmasFromDefinitions(definitions) {
  const roots = new Set();
  const defsArray = Array.isArray(definitions) ? definitions : [definitions];

  defsArray.forEach(def => {
    const rawDef = typeof def === 'string' ? def : JSON.stringify(def);
    const defText = rawDef.normalize('NFC').toLowerCase();

    // 1. Global arrow extraction (e.g., '-> haber', '-> comunicarse')
    const arrowMatches = defText.matchAll(/->\s*([\p{L}]+)/gu);
    for (const match of arrowMatches) {
      if (match[1]) {
        addRootAndReflexiveVariants(match[1].normalize('NFC'), roots);
      }
    }

    // 2. Grammatical relation pattern matching with Unicode property support
    const formMatches = defText.matchAll(
      /(?:indicative|present|past|future|subjunctive|imperative|singular|plural|person|form|conjugation|reflexive|pronominal)\s+(?:form\s+|verb\s+)?(?:of|from)\s+([\p{L}]+)/gu
    );
    for (const match of formMatches) {
      if (match[1]) {
        addRootAndReflexiveVariants(match[1].normalize('NFC'), roots);
      }
    }
  });

  return Array.from(roots);
}

/**
 * Universal Entry Lemma Extractor.
 * Handles both textual definitions AND Yomichan/YomiTan explicit tuple inflection banks.
 */
function extractLemmasFromEntry(entry) {
  const roots = new Set();

  if (!Array.isArray(entry) || entry.length === 0) {
    return { term: null, lemmas: [] };
  }

  const rawTerm = entry[0];
  if (!rawTerm || typeof rawTerm !== 'string') {
    return { term: null, lemmas: [] };
  }

  const cleanTerm = rawTerm.normalize('NFC').toLowerCase().trim();

  // Handle Index 5 (Yomichan definition OR Inflection bank tuple array)
  if (entry.length > 5 && entry[5] != null) {
    const field5 = entry[5];

    if (Array.isArray(field5)) {
      let containsTuples = false;

      field5.forEach(item => {
        // Form: [ "bastar", ["third-person plural..."] ]
        if (Array.isArray(item) && item.length > 0 && typeof item[0] === 'string') {
          containsTuples = true;
          addRootAndReflexiveVariants(item[0], roots);
        } 
        // Form: { headword: "bastar" }
        else if (typeof item === 'object' && item !== null && item.headword) {
          containsTuples = true;
          addRootAndReflexiveVariants(item.headword, roots);
        }
      });

      // If field5 wasn't an array of tuples, parse it as standard definitions
      if (!containsTuples) {
        const defLemmas = extractLemmasFromDefinitions(field5);
        defLemmas.forEach(l => addRootAndReflexiveVariants(l, roots));
      }
    } else {
      // Direct string definition
      const defLemmas = extractLemmasFromDefinitions(field5);
      defLemmas.forEach(l => addRootAndReflexiveVariants(l, roots));
    }
  }

  return { term: cleanTerm, lemmas: Array.from(roots) };
}

// --- AnkiConnect API Helper ---
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
      if (res.ok) return await res.json();
    } catch (err) {
      lastError = err;
    }
  }
  throw new Error(`AnkiConnect connection failed: ${lastError?.message || 'Unreachable'}`);
}

// --- Text Sanitization & Tokenization ---
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

// --- Direct Anki Sync Engine ---
async function syncAnkiWordsDirect(targetDeck, targetField) {
  const safeDeck = targetDeck.replace(/"/g, '\\"');

  const findNotesRes = await invoke('findNotes', { query: `deck:"${safeDeck}"` });
  if (findNotesRes.error) throw new Error(`AnkiConnect Error: ${findNotesRes.error}`);

  const noteIds = findNotesRes.result;
  if (!noteIds || noteIds.length === 0) {
    await chrome.storage.local.set({ spanishWords: {} });
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
  
  const [activeTab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (activeTab?.id) {
    chrome.tabs.sendMessage(activeTab.id, { action: 'SETTINGS_UPDATED' }).catch(() => {});
  }

  return Object.keys(wordCache).length;
}

// --- Yomitan Zip Dictionary Import Handler ---
async function handleDictionaryImport() {
  const dictInput = document.getElementById('dictInput');
  const importDictBtn = document.getElementById('importDictBtn');
  
  if (!dictInput || !dictInput.files || dictInput.files.length === 0) {
    showStatus('Please select a Yomitan dictionary .zip file.', 'error');
    return;
  }

  const file = dictInput.files[0];
  if (!file.name.endsWith('.zip')) {
    showStatus('Invalid format. Please upload a Yomitan .zip file.', 'error');
    return;
  }

  try {
    importDictBtn.disabled = true;
    showStatus('Opening dictionary ZIP archive...', 'info');

    const zip = await JSZip.loadAsync(file);
    const dictionaryFiles = Object.keys(zip.files).filter(name =>
      name.endsWith('.json') &&
      !name.startsWith('__MACOSX') &&
      !name.endsWith('index.json') &&
      !name.includes('tag_bank')
    );

    if (dictionaryFiles.length === 0) {
      throw new Error('No valid term bank or inflection bank JSON files found in ZIP archive.');
    }

    const lemmatizationRules = (await getIDB('lemmatizationRules')) || {};
    const existingDictionaryWords = (await chrome.storage.local.get(['dictionaryWords'])).dictionaryWords || [];
    const dictionaryWords = new Set(existingDictionaryWords);
    let totalTermsProcessed = 0;
    let rulesAdded = 0;

    for (let i = 0; i < dictionaryFiles.length; i++) {
      const fileName = dictionaryFiles[i];
      const progressPct = Math.round(((i + 1) / dictionaryFiles.length) * 100);
      showStatus(`Parsing ${fileName}... (${progressPct}% complete)`, 'info');

      const jsonText = await zip.file(fileName).async('string');
      const termEntries = JSON.parse(jsonText);

      if (Array.isArray(termEntries)) {
        termEntries.forEach(entry => {
          const { term, lemmas } = extractLemmasFromEntry(entry);

          if (term) {
            // Every headword the dictionary recognizes counts as a "known" word
            // for unknown-word detection, whether or not it resolved to a lemma.
            dictionaryWords.add(term);
          }

          if (term && lemmas.length > 0) {
            const existing = new Set(lemmatizationRules[term] || []);
            lemmas.forEach(l => {
              existing.add(l);
              dictionaryWords.add(l); // Lemma roots are recognized words too.
            });
            lemmatizationRules[term] = Array.from(existing);
            rulesAdded++;
          }
          totalTermsProcessed++;
        });
      }
    }

    showStatus('Saving dictionary rules...', 'info');
    await putIDB('lemmatizationRules', lemmatizationRules);
    // Stored via chrome.storage.local (not IndexedDB) specifically because
    // content.js needs to read this. Content scripts run in the webpage's own
    // origin, not the extension's -- indexedDB there would be a totally
    // separate, empty database. chrome.storage.local is the API that's
    // actually shared across extension contexts (background/options/content).
    await chrome.storage.local.set({ dictionaryWords: Array.from(dictionaryWords) });

    showStatus(`Import complete! Parsed ${totalTermsProcessed} terms & extracted ${rulesAdded} lemma rules.`, 'success');
    updateStatsInfo();

  } catch (err) {
    console.error('Dictionary import error:', err);
    showStatus(`Import failed: ${err.message}`, 'error');
  } finally {
    importDictBtn.disabled = false;
  }
}

// --- UI Population Functions ---
async function loadDecksAndFields() {
  const deckSelect = document.getElementById('deckSelect');
  const fieldSelect = document.getElementById('fieldSelect');

  try {
    showStatus('Connecting to AnkiConnect...', 'info');
    const res = await invoke('deckNames');
    if (res.error || !res.result) throw new Error(res.error || 'No decks returned');

    const decks = res.result;
    const { selectedDeck, selectedField } = await chrome.storage.local.get(['selectedDeck', 'selectedField']);

    deckSelect.innerHTML = '';
    decks.forEach(deck => {
      const opt = document.createElement('option');
      opt.value = deck;
      opt.textContent = deck;
      if (deck === selectedDeck) opt.selected = true;
      deckSelect.appendChild(opt);
    });

    const activeDeck = deckSelect.value || decks[0];
    if (activeDeck) {
      await loadFieldsForDeck(activeDeck, selectedField);
    }
    showStatus('Connected to AnkiConnect', 'success');
  } catch (err) {
    console.error(err);
    deckSelect.innerHTML = '<option value="">Error connecting to Anki</option>';
    fieldSelect.innerHTML = '<option value="">Unavailable</option>';
    showStatus('Could not connect to AnkiConnect. Is Anki open?', 'error');
  }
}

async function loadFieldsForDeck(deckName, savedField) {
  const fieldSelect = document.getElementById('fieldSelect');
  try {
    const safeDeck = deckName.replace(/"/g, '\\"');
    const findRes = await invoke('findNotes', { query: `deck:"${safeDeck}"` });
    if (!findRes.result || findRes.result.length === 0) {
      fieldSelect.innerHTML = '<option value="">(No notes in deck)</option>';
      return;
    }

    const infoRes = await invoke('notesInfo', { notes: [findRes.result[0]] });
    if (infoRes.result && infoRes.result[0]) {
      const fields = Object.keys(infoRes.result[0].fields || {});
      fieldSelect.innerHTML = '';
      fields.forEach(f => {
        const opt = document.createElement('option');
        opt.value = f;
        opt.textContent = f;
        if (f === savedField) opt.selected = true;
        fieldSelect.appendChild(opt);
      });
    }
  } catch (err) {
    console.error(err);
    fieldSelect.innerHTML = '<option value="">Error loading fields</option>';
  }
}

// --- Console Debugging Helper ---
async function debugWordResolution(targetWord) {
  if (!targetWord) return console.warn('Please provide a word to test.');

  const cleanWord = String(targetWord).normalize('NFC').toLowerCase().trim();
  console.group(`🔍 Debugging Word Resolution: "${cleanWord}"`);

  const { spanishWords = {} } = await chrome.storage.local.get('spanishWords');
  const directStatus = spanishWords[cleanWord];

  console.log(
    `Direct Cache Match:`, 
    directStatus ? `%c${directStatus.toUpperCase()}` : '%cNOT FOUND', 
    directStatus ? `color: ${directStatus === 'mature' ? '#28a745' : '#ffc107'}; font-weight: bold;` : 'color: #dc3545;'
  );

  const rules = (await getIDB('lemmatizationRules')) || {};
  const mappedRoots = rules[cleanWord];

  if (mappedRoots) {
    const rootList = Array.isArray(mappedRoots) ? mappedRoots : [mappedRoots];
    console.log(`IndexedDB Rule Found: "${cleanWord}" maps to root(s) ->`, rootList);

    const rootAnalysis = rootList.map(root => {
      const cleanRoot = String(root).normalize('NFC').toLowerCase().trim();
      return {
        'Root Lemma': cleanRoot,
        'Status in wordCache': spanishWords[cleanRoot] || 'Not in Anki Deck'
      };
    });
    console.table(rootAnalysis);
  } else {
    console.log(`IndexedDB Rule: No lemmatization entry found for "${cleanWord}".`);
  }

  console.groupEnd();
}

window.debugWordResolution = debugWordResolution;

// --- Event Listeners Initialization ---
document.addEventListener('DOMContentLoaded', () => {
  loadDecksAndFields();
  updateStatsInfo();

  const deckSelect = document.getElementById('deckSelect');
  const saveDeckBtn = document.getElementById('saveDeckBtn');
  const clearDataBtn = document.getElementById('clearDataBtn');
  const importDictBtn = document.getElementById('importDictBtn');
  const suspendedOverrideToggle = document.getElementById('suspendedOverrideToggle');
  const suspendedOverrideStatus = document.getElementById('suspendedOverrideStatus');

  // --- Suspended Card Handling: load saved state ---
  chrome.storage.local.get(['suspendedOverrideEnabled', 'suspendedOverrideStatus'], (data) => {
    if (suspendedOverrideToggle) {
      suspendedOverrideToggle.checked = !!data.suspendedOverrideEnabled;
    }
    if (suspendedOverrideStatus) {
      suspendedOverrideStatus.value = data.suspendedOverrideStatus || 'mature';
      suspendedOverrideStatus.disabled = !data.suspendedOverrideEnabled;
    }
  });

  // Re-runs the sync using whatever deck/field is currently saved, so a change
  // to the suspended-card setting takes effect immediately rather than only on
  // the next manual sync. Safe to call even if nothing has been saved yet.
  async function resyncWithSavedDeck() {
    const { selectedDeck, selectedField } = await chrome.storage.local.get(['selectedDeck', 'selectedField']);
    if (!selectedDeck || !selectedField) return;

    try {
      showStatus('Re-syncing with updated suspended-card settings...', 'info');
      const wordCount = await syncAnkiWordsDirect(selectedDeck, selectedField);
      showStatus(`Successfully synced ${wordCount} words!`, 'success');
      updateStatsInfo();
    } catch (err) {
      console.error(err);
      showStatus(`Sync failed: ${err.message}`, 'error');
    }
  }

  suspendedOverrideToggle?.addEventListener('change', () => {
    const enabled = suspendedOverrideToggle.checked;
    if (suspendedOverrideStatus) {
      suspendedOverrideStatus.disabled = !enabled;
    }
    chrome.storage.local.set({ suspendedOverrideEnabled: enabled }, resyncWithSavedDeck);
  });

  suspendedOverrideStatus?.addEventListener('change', () => {
    chrome.storage.local.set({ suspendedOverrideStatus: suspendedOverrideStatus.value }, resyncWithSavedDeck);
  });

  // Deck Select Change -> Reload Fields
  deckSelect?.addEventListener('change', (e) => {
    loadFieldsForDeck(e.target.value);
  });

  // Dictionary Import Event Listener
  importDictBtn?.addEventListener('click', handleDictionaryImport);

  // Save Deck Settings & Sync
  saveDeckBtn?.addEventListener('click', async () => {
    const selectedDeck = document.getElementById('deckSelect').value;
    const selectedField = document.getElementById('fieldSelect').value;

    if (!selectedDeck || !selectedField) {
      showStatus('Please select a valid deck and field.', 'error');
      return;
    }

    try {
      saveDeckBtn.disabled = true;
      showStatus('Syncing Anki words...', 'info');

      await chrome.storage.local.set({ selectedDeck, selectedField });
      const wordCount = await syncAnkiWordsDirect(selectedDeck, selectedField);

      showStatus(`Successfully synced ${wordCount} words!`, 'success');
      updateStatsInfo();
    } catch (err) {
      console.error(err);
      showStatus(`Sync failed: ${err.message}`, 'error');
    } finally {
      saveDeckBtn.disabled = false;
    }
  });

  // Clear Extension Data
  clearDataBtn?.addEventListener('click', async () => {
    if (confirm('Are you sure you want to clear all stored extension data and cached words?')) {
      await chrome.storage.local.clear();
      await clearIDB();
      if (suspendedOverrideToggle) suspendedOverrideToggle.checked = false;
      if (suspendedOverrideStatus) {
        suspendedOverrideStatus.value = 'mature';
        suspendedOverrideStatus.disabled = true;
      }
      showStatus('All extension data cleared.', 'success');
      updateStatsInfo();
    }
  });
});