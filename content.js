// content.js - High-performance Spanish vocabulary highlighter

let wordCache = {};
let activeWordMap = {};
let dictionaryWordSet = new Set();
let config = {
  highlightEnabled: true,
  annotationStyle: 'highlight',
  colorLearning: '#ffc107',
  colorMature: '#28a745',
  colorUnknown: '#6b7280',
  highlightLearningEnabled: true,
  highlightMatureEnabled: true,
  highlightUnknownEnabled: true
};

let dynamicPageObserver = null;
let scanDebounceTimeout = null;

// 1. Initial Load & Setup
async function loadSettingsAndRun() {
  const data = await chrome.storage.local.get([
    'spanishWords',
    'dictionaryWords',
    'highlightEnabled',
    'annotationStyle',
    'colorLearning',
    'colorMature',
    'colorUnknown',
    'highlightLearningEnabled',
    'highlightMatureEnabled',
    'highlightUnknownEnabled'
  ]);

  if (data.spanishWords) wordCache = data.spanishWords;
  if (data.highlightEnabled !== undefined) config.highlightEnabled = data.highlightEnabled;
  if (data.annotationStyle) config.annotationStyle = data.annotationStyle;
  if (data.colorLearning) config.colorLearning = data.colorLearning;
  if (data.colorMature) config.colorMature = data.colorMature;
  if (data.colorUnknown) config.colorUnknown = data.colorUnknown;
  if (data.highlightLearningEnabled !== undefined) config.highlightLearningEnabled = data.highlightLearningEnabled;
  if (data.highlightMatureEnabled !== undefined) config.highlightMatureEnabled = data.highlightMatureEnabled;
  if (data.highlightUnknownEnabled !== undefined) config.highlightUnknownEnabled = data.highlightUnknownEnabled;

  // Read via chrome.storage.local (not IndexedDB) -- content scripts run in
  // the webpage's own origin, so raw indexedDB here would be a separate,
  // empty database, never the one the extension's options/background pages
  // write to. chrome.storage.local is what's actually shared cross-context.
  // Checked only as a fallback (see runHighlighter), so an Anki-known word
  // can never be shadowed by its "unknown" dictionary status.
  const dictionaryWordsArr = data.dictionaryWords || [];
  dictionaryWordSet = new Set(
    dictionaryWordsArr.map(w => String(w).normalize('NFC').toLowerCase().trim())
  );

  buildActiveWordMap();

  stopDynamicObserver();
  removeHighlights();

  if (config.highlightEnabled && (Object.keys(activeWordMap).length > 0 || dictionaryWordSet.size > 0)) {
    runHighlighter(document.body);
    startDynamicObserver();
  }
}

loadSettingsAndRun();

chrome.runtime.onMessage.addListener((message) => {
  if (message.action === 'SETTINGS_UPDATED') {
    loadSettingsAndRun();
  }
});

function buildActiveWordMap() {
  // wordCache already has inflected-form statuses fully propagated via
  // lemmatizationRules server-side, during sync (background.js/options.js run
  // in the extension's own origin, where that data actually lives) -- no
  // client-side lemmatization pass is needed or possible here.
  activeWordMap = { ...wordCache };
}

// 2. Fast Token-Based DOM Highlighter
function runHighlighter(rootElement = document.body) {
  if (!rootElement || !config.highlightEnabled) return;

  const ignoredTags = new Set([
    'SCRIPT', 'STYLE', 'INPUT', 'TEXTAREA', 'NOSCRIPT', 'CODE', 
    'PRE', 'MARK', 'SVG', 'CANVAS', 'VIDEO', 'AUDIO', 'IFRAME'
  ]);

  const walker = document.createTreeWalker(
    rootElement,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode: (node) => {
        const parent = node.parentElement;
        if (!parent) return NodeFilter.FILTER_REJECT;

        if (
          ignoredTags.has(parent.tagName) || 
          parent.isContentEditable || 
          parent.closest('.anki-highlight, .html5-video-player, #movie_player, ytd-player')
        ) {
          return NodeFilter.FILTER_REJECT;
        }

        if (!node.nodeValue || node.nodeValue.trim().length < 2) {
          return NodeFilter.FILTER_SKIP;
        }

        return NodeFilter.FILTER_ACCEPT;
      }
    }
  );

  const textNodes = [];
  while (walker.nextNode()) {
    textNodes.push(walker.currentNode);
  }

  const wordTokenRegex = /[\p{L}\p{M}\p{N}_]+/gu;

  textNodes.forEach(node => {
    const text = node.nodeValue;
    if (!text) return;

    wordTokenRegex.lastIndex = 0;
    let match;
    let lastIndex = 0;
    let hasMatches = false;
    const fragment = document.createDocumentFragment();

    while ((match = wordTokenRegex.exec(text)) !== null) {
      const matchedWord = match[0];
      const matchIndex = match.index;
      const normalizedWord = matchedWord.normalize('NFC').toLowerCase();

      const status = activeWordMap[normalizedWord] ||
        (dictionaryWordSet.has(normalizedWord) ? 'unknown' : undefined);
      const categoryEnabled =
        status === 'mature' ? config.highlightMatureEnabled :
        status === 'unknown' ? config.highlightUnknownEnabled :
        status === 'learning' ? config.highlightLearningEnabled :
        false;

      if (status && categoryEnabled) {
        hasMatches = true;
        const targetColor =
          status === 'mature' ? config.colorMature :
          status === 'unknown' ? config.colorUnknown :
          config.colorLearning;

        if (matchIndex > lastIndex) {
          fragment.appendChild(document.createTextNode(text.substring(lastIndex, matchIndex)));
        }

        const marker = document.createElement('mark');
        marker.className = 'anki-highlight';
        marker.textContent = matchedWord;

        marker.style.backgroundColor = 'transparent';
        marker.style.color = 'inherit';
        marker.style.padding = '0';
        marker.style.borderRadius = '0';
        marker.style.display = 'inline';

        if (config.annotationStyle === 'underline') {
          marker.style.borderBottom = `2px dashed ${targetColor}`;
          marker.style.textDecoration = 'none';
        } else if (config.annotationStyle === 'textcolor') {
          marker.style.color = targetColor;
        } else {
          marker.style.backgroundColor = targetColor;
          marker.style.color = status === 'learning' ? '#333333' : '#ffffff';
          marker.style.borderRadius = '3px';
          marker.style.padding = '0 2px';
        }

        fragment.appendChild(marker);
        lastIndex = matchIndex + matchedWord.length;
      }
    }

    if (hasMatches) {
      if (lastIndex < text.length) {
        fragment.appendChild(document.createTextNode(text.substring(lastIndex)));
      }
      if (node.parentNode) {
        node.parentNode.replaceChild(fragment, node);
      }
    }
  });
}

// 3. Incremental Dynamic Observer
function startDynamicObserver() {
  if (dynamicPageObserver) return;

  dynamicPageObserver = new MutationObserver((mutations) => {
    const addedElements = [];

    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType === 1) {
          if (
            !node.classList?.contains('anki-highlight') &&
            !node.closest?.('.html5-video-player, #movie_player, ytd-player')
          ) {
            addedElements.push(node);
          }
        }
      }
    }

    if (addedElements.length > 0) {
      clearTimeout(scanDebounceTimeout);
      scanDebounceTimeout = setTimeout(() => {
        if (config.highlightEnabled && (Object.keys(activeWordMap).length > 0 || dictionaryWordSet.size > 0)) {
          addedElements.forEach(el => runHighlighter(el));
        }
      }, 500);
    }
  });

  dynamicPageObserver.observe(document.body, { childList: true, subtree: true });
}

function stopDynamicObserver() {
  if (dynamicPageObserver) {
    dynamicPageObserver.disconnect();
    dynamicPageObserver = null;
  }
  clearTimeout(scanDebounceTimeout);
}

function removeHighlights() {
  stopDynamicObserver();
  const highlights = document.querySelectorAll('.anki-highlight');
  
  highlights.forEach(el => {
    const parent = el.parentNode;
    if (parent) {
      parent.replaceChild(document.createTextNode(el.textContent), el);
      parent.normalize();
    }
  });

  if (config.highlightEnabled && (Object.keys(activeWordMap).length > 0 || dictionaryWordSet.size > 0)) {
    startDynamicObserver();
  }
}