# AGENTS.md

## Project Overview
This is a **Chrome browser extension** (Manifest V3) called "Anki Spanish Sync".
It is NOT a web application — it has no server, no build step, and no package.json.

## What It Does
- Syncs Spanish vocabulary from Anki via AnkiConnect (localhost:8765)
- Highlights Spanish words on any web page by learning status (learning/mature/unknown)
- Popup UI: annotation toggles, style mode, color pickers per category
- Options page: deck/field selection, Yomitan dictionary import, suspended card handling
- Content script: DOM tree-walker highlighter with MutationObserver for dynamic pages

## Files
- `manifest.json` — MV3 manifest (permissions: storage, activeTab; host: all URLs + localhost:8765)
- `popup.html` / `popup.js` — extension popup UI
- `options.html` / `options.js` — settings page (deck config, dictionary import)
- `background.js` — service worker (AnkiConnect sync engine)
- `content.js` — content script (page annotation highlighter)
- `jszip_min.js` — JSZip for Yomitan dictionary ZIP import

## Running in Base44 Preview
The extension cannot run as a web app. For preview purposes:
- `docker-compose.base44.yml` serves the files via nginx on port 3000
- `index.html` is a landing page linking to popup.html and options.html
- `chrome-shim.js` mocks `chrome.storage`, `chrome.runtime`, `chrome.tabs` APIs so the UI is interactive outside the extension context
- popup.html and options.html conditionally load the shim only when `chrome.storage` is unavailable (so the real extension is unaffected)
- Full functionality requires loading as an unpacked extension in Chrome at `chrome://extensions`

## No External Secrets Required
All data is local (chrome.storage, IndexedDB, AnkiConnect on localhost). No external API credentials needed.
