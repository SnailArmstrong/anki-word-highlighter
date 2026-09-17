// chrome-shim.js — Mock Chrome extension APIs for preview/static serving.
// Only loaded when chrome.storage is unavailable (i.e. NOT running as an extension).
// Lets the popup and options UI render and be interactive outside the extension context.

(function () {
  if (typeof chrome !== 'undefined' && chrome.storage && chrome.storage.local) return;

  // --- Seed default data so the UI looks alive ---
  const SEED = {
    spanishWords: {
      'tener': 'mature', 'tiene': 'mature', 'tenía': 'mature',
      'hacer': 'mature', 'hago': 'mature', 'hacía': 'mature',
      'decir': 'mature', 'dice': 'mature', 'dijo': 'mature',
      'ir': 'mature', 'voy': 'mature', 'fui': 'mature',
      'ver': 'mature', 'veo': 'mature', 'vio': 'mature',
      'comer': 'learning', 'como': 'learning', 'comió': 'learning',
      'hablar': 'learning', 'hablo': 'learning', 'habló': 'learning',
      'aprender': 'learning', 'aprendo': 'learning',
      'trabajar': 'learning', 'trabajo': 'learning',
      'estudiar': 'learning', 'estudio': 'learning',
      'caminar': 'unknown', 'nadar': 'unknown', 'saltar': 'unknown',
      'correr': 'unknown', 'escribir': 'unknown', 'leer': 'unknown'
    },
    highlightEnabled: true,
    annotationStyle: 'highlight',
    colorLearning: '#ffc107',
    colorMature: '#28a745',
    colorUnknown: '#6b7280',
    highlightLearningEnabled: true,
    highlightMatureEnabled: true,
    highlightUnknownEnabled: true,
    selectedDeck: 'Mined word',
    selectedField: 'Spanish Word',
    suspendedOverrideEnabled: false,
    suspendedOverrideStatus: 'mature',
    dictionaryWords: ['caminar', 'nadar', 'saltar', 'correr', 'escribir', 'leer']
  };

  // Initialize localStorage with seed data (only keys not already present)
  Object.keys(SEED).forEach(function (key) {
    if (localStorage.getItem('shim_' + key) === null) {
      localStorage.setItem('shim_' + key, JSON.stringify(SEED[key]));
    }
  });

  function getKeys(keys) {
    var result = {};
    var keyList = Array.isArray(keys) ? keys : (keys ? Object.keys(keys) : []);
    keyList.forEach(function (k) {
      var raw = localStorage.getItem('shim_' + k);
      if (raw !== null) result[k] = JSON.parse(raw);
    });
    return result;
  }

  var mockTabs = [{ id: 1, url: 'https://example.com' }];

  var mockChrome = {
    storage: {
      local: {
        get: function (keys, callback) {
          var data = getKeys(keys);
          if (callback) setTimeout(function () { callback(data); }, 10);
          return Promise.resolve(data);
        },
        set: function (obj, callback) {
          Object.keys(obj).forEach(function (k) {
            localStorage.setItem('shim_' + k, JSON.stringify(obj[k]));
          });
          if (callback) setTimeout(callback, 10);
        },
        clear: function (callback) {
          Object.keys(localStorage).filter(function (k) {
            return k.startsWith('shim_');
          }).forEach(function (k) { localStorage.removeItem(k); });
          if (callback) setTimeout(callback, 10);
        }
      }
    },
    runtime: {
      getURL: function (path) { return path; },
      sendMessage: function (message, callback) {
        // Mock FORCE_SYNC response
        if (message && message.action === 'FORCE_SYNC') {
          var data = getKeys(['spanishWords']);
          var count = data.spanishWords ? Object.keys(data.spanishWords).length : 0;
          var resp = { success: true, count: count };
          if (callback) setTimeout(function () { callback(resp); }, 500);
          return Promise.resolve(resp);
        }
        if (callback) setTimeout(function () { callback({ success: true }); }, 10);
        return Promise.resolve({ success: true });
      },
      onMessage: { addListener: function () {} },
      onInstalled: { addListener: function () {} }
    },
    tabs: {
      query: function (query, callback) {
        var tabs = mockTabs;
        if (query && query.active) tabs = mockTabs.slice(0, 1);
        if (callback) setTimeout(function () { callback(tabs); }, 10);
        return Promise.resolve(tabs);
      },
      sendMessage: function (tabId, message) {
        return Promise.resolve({ ok: true });
      },
      create: function (props) {
        if (props && props.url) window.open(props.url, '_blank');
      }
    }
  };

  // Expose as chrome global
  window.chrome = mockChrome;
})();
