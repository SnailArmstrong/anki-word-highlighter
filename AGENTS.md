# Anki Spanish Sync — Base44 Dev Environment

## Project Type
This is a **Chrome Manifest V3 browser extension**, not a web application. It cannot be "run" as a web server in the traditional sense — it must be loaded as an unpacked extension in Chrome (`chrome://extensions` → Developer Mode → Load unpacked).

## What the Extension Does
- Syncs Spanish vocabulary from Anki decks via AnkiConnect (localhost:8765)
- Highlights/annotates Spanish words on web pages by learning status (Learning / Mature / Unknown)
- Popup UI: annotation style toggles, color pickers, manual sync button
- Options page: deck/field selection, Yomitan dictionary import, suspended card handling

## Preview Setup
Since this is a browser extension (not a web app), the preview serves the extension's static HTML pages via nginx on port 3000 so the UI is visible. The interactive features (AnkiConnect sync, content script injection, Chrome storage APIs) only work when loaded as a real Chrome extension — they rely on `chrome.*` APIs unavailable in a regular web page.

- `index.html` — landing page linking to popup and options pages
- `docker-compose.base44.yml` — nginx:alpine serving static files on port 3000
- `preview-nginx.conf` — custom nginx config (runs as root to read the bind-mounted directory)

## No External Secrets Required
The extension connects to AnkiConnect on localhost:8765 (the user's local Anki desktop app). No external API keys or credentials are needed.

## Files
- `manifest.json` — MV3 manifest
- `background.js` — service worker (AnkiConnect sync engine)
- `content.js` — content script (DOM highlighter)
- `popup.html` / `popup.js` — extension popup UI
- `options.html` / `options.js` — advanced settings page
- `jszip_min.js` — JSZip library for dictionary import
