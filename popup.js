document.addEventListener('DOMContentLoaded', () => {
  const syncBtn = document.getElementById('sync-btn');
  const openSettingsBtn = document.getElementById('open-settings-btn');
  const wordCountSpan = document.getElementById('word-count');
  const statusSpan = document.getElementById('sync-status');
  const highlightToggle = document.getElementById('highlight-toggle');
  const styleModeSelect = document.getElementById('style-mode-select');

  const learningEnabledToggle = document.getElementById('learning-enabled-toggle');
  const matureEnabledToggle = document.getElementById('mature-enabled-toggle');
  const unknownEnabledToggle = document.getElementById('unknown-enabled-toggle');

  const modalBackdrop = document.getElementById('swatch-modal-backdrop');
  const modalTitle = document.getElementById('swatch-modal-title');
  const modalOptions = document.getElementById('swatch-modal-options');
  const modalClose = document.getElementById('swatch-modal-close');

  const DEFAULT_SETTINGS = {
    highlightEnabled: true,
    annotationStyle: 'highlight',
    colorLearning: '#ffc107',
    colorMature: '#28a745',
    colorUnknown: '#6b7280',
    highlightLearningEnabled: true,
    highlightMatureEnabled: true,
    highlightUnknownEnabled: true
  };

  // Curated swatch palettes shown per category (kept as fixed presets, same
  // spirit as the old <select> options, just rendered as color squares now).
  const SWATCH_PALETTES = {
    learning: { label: 'Learning Color', colors: ['#ffc107', '#fd7e14', '#e83e8c', '#007bff', '#6f42c1'] },
    mature: { label: 'Mature Color', colors: ['#28a745', '#20c997', '#17a2b8', '#dc3545', '#343a40'] },
    unknown: { label: 'Unknown Color', colors: ['#6b7280', '#9333ea', '#0ea5e9', '#f43f5e', '#78716c'] }
  };

  function notifyContentScripts() {
    chrome.tabs.query({}, (tabs) => {
      tabs.forEach((tab) => {
        if (tab.url && (tab.url.startsWith('http://') || tab.url.startsWith('https://'))) {
          chrome.tabs.sendMessage(tab.id, { action: 'SETTINGS_UPDATED' }).catch(() => {});
        }
      });
    });
  }

  // --- Shared bottom-sheet color picker ---
  // A single modal reused by all three category swatch buttons, so opening a
  // picker can never overlap or block other rows in the small popup panel
  // (unlike an inline dropdown, which has nowhere to expand into).
  function openSwatchModal(paletteKey, storageKey, btn) {
    const palette = SWATCH_PALETTES[paletteKey];
    modalTitle.textContent = palette.label;
    modalOptions.innerHTML = '';

    chrome.storage.local.get([storageKey], (data) => {
      const currentColor = data[storageKey] || DEFAULT_SETTINGS[storageKey];

      palette.colors.forEach(color => {
        const opt = document.createElement('button');
        opt.type = 'button';
        opt.className = 'modal-swatch-option';
        opt.style.backgroundColor = color;
        opt.setAttribute('aria-label', color);
        if (color === currentColor) opt.classList.add('active');

        opt.addEventListener('click', () => {
          btn.style.backgroundColor = color;
          chrome.storage.local.set({ [storageKey]: color }, () => notifyContentScripts());
          closeSwatchModal();
        });

        modalOptions.appendChild(opt);
      });

      modalBackdrop.hidden = false;
    });
  }

  function closeSwatchModal() {
    modalBackdrop.hidden = true;
  }

  modalClose.addEventListener('click', closeSwatchModal);
  modalBackdrop.addEventListener('click', (e) => {
    if (e.target === modalBackdrop) closeSwatchModal();
  });

  function setupSwatchButton(btnId, paletteKey, storageKey, defaultColor) {
    const btn = document.getElementById(btnId);
    if (!btn) return;

    chrome.storage.local.get([storageKey], (data) => {
      btn.style.backgroundColor = data[storageKey] || defaultColor;
    });

    btn.addEventListener('click', () => openSwatchModal(paletteKey, storageKey, btn));
  }

  setupSwatchButton('learning-swatch-btn', 'learning', 'colorLearning', DEFAULT_SETTINGS.colorLearning);
  setupSwatchButton('mature-swatch-btn', 'mature', 'colorMature', DEFAULT_SETTINGS.colorMature);
  setupSwatchButton('unknown-swatch-btn', 'unknown', 'colorUnknown', DEFAULT_SETTINGS.colorUnknown);

  // Open Options / Settings page (deck & field selection, dictionary import) on tap
  if (openSettingsBtn) {
    openSettingsBtn.addEventListener('click', () => {
      chrome.tabs.create({ url: chrome.runtime.getURL('options.html') });
    });
  }

  // Initial Settings Load
  chrome.storage.local.get([
    'spanishWords',
    'highlightEnabled',
    'annotationStyle',
    'highlightLearningEnabled',
    'highlightMatureEnabled',
    'highlightUnknownEnabled'
  ], (data) => {
    if (data.spanishWords && wordCountSpan) {
      wordCountSpan.textContent = Object.keys(data.spanishWords).length;
    }
    if (highlightToggle) {
      highlightToggle.checked = data.highlightEnabled !== undefined ? data.highlightEnabled : DEFAULT_SETTINGS.highlightEnabled;
    }
    if (styleModeSelect) {
      styleModeSelect.value = data.annotationStyle || DEFAULT_SETTINGS.annotationStyle;
    }
    if (learningEnabledToggle) {
      learningEnabledToggle.checked = data.highlightLearningEnabled !== undefined ? data.highlightLearningEnabled : DEFAULT_SETTINGS.highlightLearningEnabled;
    }
    if (matureEnabledToggle) {
      matureEnabledToggle.checked = data.highlightMatureEnabled !== undefined ? data.highlightMatureEnabled : DEFAULT_SETTINGS.highlightMatureEnabled;
    }
    if (unknownEnabledToggle) {
      unknownEnabledToggle.checked = data.highlightUnknownEnabled !== undefined ? data.highlightUnknownEnabled : DEFAULT_SETTINGS.highlightUnknownEnabled;
    }
  });

  if (styleModeSelect) {
    styleModeSelect.addEventListener('change', () => {
      chrome.storage.local.set({ annotationStyle: styleModeSelect.value }, () => notifyContentScripts());
    });
  }

  if (highlightToggle) {
    highlightToggle.addEventListener('change', () => {
      chrome.storage.local.set({ highlightEnabled: highlightToggle.checked }, () => notifyContentScripts());
    });
  }

  if (learningEnabledToggle) {
    learningEnabledToggle.addEventListener('change', () => {
      chrome.storage.local.set({ highlightLearningEnabled: learningEnabledToggle.checked }, () => notifyContentScripts());
    });
  }
  if (matureEnabledToggle) {
    matureEnabledToggle.addEventListener('change', () => {
      chrome.storage.local.set({ highlightMatureEnabled: matureEnabledToggle.checked }, () => notifyContentScripts());
    });
  }
  if (unknownEnabledToggle) {
    unknownEnabledToggle.addEventListener('change', () => {
      chrome.storage.local.set({ highlightUnknownEnabled: unknownEnabledToggle.checked }, () => notifyContentScripts());
    });
  }

  if (syncBtn) {
    syncBtn.addEventListener('click', () => {
      syncBtn.disabled = true;
      if (statusSpan) {
        statusSpan.textContent = 'Syncing...';
        statusSpan.style.color = '#ffc107';
      }
      chrome.runtime.sendMessage({ action: 'FORCE_SYNC' }, (response) => {
        if (response && response.success) {
          if (wordCountSpan) wordCountSpan.textContent = response.count;
          if (statusSpan) {
            statusSpan.textContent = 'Updated!';
            statusSpan.style.color = '#28a745';
          }
          notifyContentScripts();
        } else {
          if (statusSpan) {
            statusSpan.textContent = 'Error!';
            statusSpan.style.color = '#dc3545';
          }
          alert(response?.error || 'Sync fail. Check connection.');
        }
        setTimeout(() => {
          if (statusSpan) {
            statusSpan.textContent = 'Ready';
            statusSpan.style.color = '#28a745';
          }
          syncBtn.disabled = false;
        }, 2000);
      });
    });
  }
});
