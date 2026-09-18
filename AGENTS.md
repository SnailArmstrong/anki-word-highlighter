# AGENTS.md

## Project Overview
A Spanish vocabulary highlighter for language learning. Originally a Chrome
browser extension (Manifest V3), now being ported to a **Flutter Android app**.

### Chrome Extension (original, in repo root)
- `manifest.json` — MV3 manifest
- `popup.html` / `popup.js` — extension popup UI
- `options.html` / `options.js` — settings page
- `background.js` — service worker (AnkiConnect sync)
- `content.js` — content script (page annotation)
- `jszip_min.js` — JSZip for dictionary import

### Flutter App (in `flutter_app/`)
- `lib/main.dart` — entry point with Provider
- `lib/app_model.dart` — central state (settings, word cache, sync)
- `lib/theme.dart` — dark theme matching extension palette
- `lib/services/word_utils.dart` — ported: extractSpanishWords, getWordVariants, lemma extraction
- `lib/services/highlight_engine.dart` — ported: text tokenizer + word status highlighter
- `lib/services/anki_sync_service.dart` — AnkiDroid sync (mock data for web preview)
- `lib/services/dictionary_service.dart` — Yomitan .zip dictionary import
- `lib/services/file_parser.dart` — EPUB/TXT file parsing
- `lib/services/subtitle_parser.dart` — SRT/VTT subtitle parsing into cues with timing
- `lib/services/web_blob.dart` — conditional import for blob URL creation (web-only)
- `lib/screens/home_screen.dart` — bottom nav (Reader, Video, Settings)
- `lib/screens/reader_tab.dart` — ebook/text reader with highlighting
- `lib/screens/video_tab.dart` — video player with SRT/VTT subtitle support and word highlighting
- `lib/screens/settings_tab.dart` — all settings in expandable categories (sync, annotation, colors, deck, suspended cards, data management)
- `lib/widgets/highlighted_text.dart` — RichText with color-coded word spans
- `lib/widgets/word_detail_sheet.dart` — bottom sheet for word details

## Running in Base44 Preview
- `docker-compose.base44.yml` uses `ghcr.io/cirruslabs/flutter:latest`
- Runs `flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0`
- The Flutter web build is served on port 3000
- AnkiDroid integration uses mock data on web (platform channel for Android)
- The extension's static preview files (index.html, chrome-shim.js, nginx.conf) remain in the repo but are no longer served

## Key Ports
- Core logic ported from JS to Dart: extractSpanishWords, getWordVariants, extractLemmasFromEntry, extractLemmasFromDefinitions, highlight tokenization
- AnkiDroid sync is stubbed with mock data; real implementation needs Android platform channel to com.ichi2.anki.FlashCardsProvider

## No External Secrets Required
All data is local. No external API credentials needed.
