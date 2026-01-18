# MemoFlow

Chinese version: [README.md](README.md)

MemoFlow is a Flutter mobile client for the Memos backend. It is an independent, third-party
project and is not affiliated with or endorsed by the official Memos project.

## Features
- Offline-first sync with local SQLite storage and an outbox queue for retries.
- Create, edit, search, pin, archive, and delete memos with Markdown, tags, and tasks.
- Quick input sheet with drafts, tag suggestions, memo links, attachments, camera capture, and undo/redo.
- Attachments browser with image preview and audio playback; voice memo recording.
- Random daily review and local stats (monthly charts and activity heatmap) with sharing.
- AI summary reports with configurable provider/model/prompt; share poster or save as memo.
- Multi-account PAT login plus legacy API compatibility mode for older Memos servers.
- Widgets, app lock, preferences (theme, language, fonts), and Markdown+ZIP export.

## Compatibility
- Uses Memos API v1 by default.
- Enable Compatibility Mode for legacy endpoints when connecting to older servers.

## Requirements
- Flutter SDK (Dart >= 3.10.4).
- A running Memos server and a Personal Access Token (PAT).

## Run locally
The Flutter app lives in `memos_flutter_app/`.
```sh
cd memos_flutter_app
flutter pub get
flutter run
```

## Screenshots
| Login | Home |
| --- | --- |
| ![Login](docs/登录.png) | ![Home](docs/首页.png) |
| ![Navigation](docs/导航栏.png) | ![Settings](docs/设置.png) |

## Data and privacy
- Personal Access Tokens are stored via `flutter_secure_storage`.
- Memos are cached in a local SQLite database and synced via an outbox queue.
- AI summary sends selected memo content to the configured AI provider; it is not synced to the Memos backend.

## Notes
- Export outputs Markdown files inside a ZIP archive (import is not implemented yet).
- If you run into sync issues, enable network logging and export diagnostics from the app.
