# MemoFlow

<p align="center">
  <img src="docs/memoflow-logo.png" alt="MemoFlow Logo" width="120">
</p>

<p align="center">
  <a href="README.md">Chinese</a> |
  <a href="https://memoflow.hzc073.com/">Official website</a> |
  <a href="https://memoflow.hzc073.com/help/">Help Center</a>
</p>

MemoFlow is a Flutter mobile client for the [memos](https://github.com/usememos/memos) backend.

> This project is an independent third-party client
> and has no affiliation with the official Memos project.

## Download

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.memoflow.hzc073"><img src="docs/google-play-download-en.svg" alt="Download on Google Play" height="40"></a>&nbsp;
  <a href="https://github.com/hzc073/memoflow/releases/latest"><img src="docs/github-release-download-en.svg" alt="Download from GitHub Releases" height="40"></a>&nbsp;
  <a href="https://gemmm.lanzoum.com/b02vri6w2f"><img src="docs/cloud-drive-download-en.svg" alt="Download from cloud drive, password 2nor" height="40"></a>
</p>

## Community
- QQ group: `860438102`

<p align="center">
  <img src="docs/qq-group.png" alt="MemoFlow QQ group QR code" width="260">
</p>

## Features
- Login and version compatibility: supports username/password and PAT login, with Memos API version selection and probing before login (0.21-0.29).
- Offline-first: local SQLite cache + outbox retry queue, with sync queue viewing and retry support.
- Complete memo workflow: create, edit, search, pin, archive, delete, filter by tags, and browse Explore.
- Markdown and task lists: supports common Markdown rendering, task list progress display, backlinks, and linked navigation.
- Multimedia input and preview: supports attachment upload, camera capture, voice recording, image/audio/video preview, and downloads.
- Version history and trash: supports viewing/restoring memo history versions, plus restoring or permanently deleting from trash.
- Reminder system: supports memo reminders, test reminders, do-not-disturb windows, ringtone/vibration, and other reminder settings.
- Import and export: supports Markdown+ZIP export and flomo/Markdown ZIP import.
- Local library mode: supports adding and scanning local libraries, with coexistence and switching alongside server mode.
- WebDAV capabilities: supports WebDAV sync, backup/restore, retention policies, and recovery code flow.
- AI and review statistics: supports AI summaries, random reviews, statistics, and heatmap display.
- Experience and personalization: supports notification center, widgets, app lock, theme/language/font preferences, and more.

## TODO
- User
  - Authentication
    - [x] PAT login
  - Account info
    - [x] View account info
    - [x] Edit account info
    - [x] Webhook management
- Memo
  - Basics
    - [x] Create/edit/search/pin/archive/delete
  - Markdown
    - [x] Basic rendering: headings, quotes, horizontal rules, bold, italic, inline code, code blocks, unordered/ordered lists, links, images
    - [x] Custom extensions: strikethrough, task lists, tables, footnotes, highlight, underline via inline HTML
    - [x] LaTeX formulas
  - Attachments
    - [x] Browse attachments
    - [x] Image preview
    - [x] Audio playback
    - [x] Edit attachments
  - Interaction
    - [x] Likes/comments
- Other
  - [x] Offline-first sync
  - [x] Draft box
  - [x] Standalone mode
  - [x] AI summary
  - [ ] Speech-to-text
  - [x] Custom quick tools
  - [x] Task progress bar
  - [ ] Multi-language
    <details>
    <summary>Language list (click to expand)</summary>

    - [ ] `ar` Arabic
    - [ ] `ca` Catalan
    - [ ] `cs` Czech
    - [x] `de` German
    - [x] `en` English
    - [ ] `en-GB` English (UK)
    - [ ] `es` Spanish
    - [ ] `fa` Persian
    - [ ] `fr` French
    - [ ] `gl` Galician
    - [ ] `hi` Hindi
    - [ ] `hr` Croatian
    - [ ] `hu` Hungarian
    - [ ] `id` Indonesian
    - [ ] `it` Italian
    - [x] `ja` Japanese
    - [ ] `ka-GE` Georgian
    - [ ] `ko` Korean
    - [ ] `mr` Marathi
    - [ ] `nb` Norwegian Bokmål
    - [ ] `nl` Dutch
    - [ ] `pl` Polish
    - [ ] `pt-PT` Portuguese (Portugal)
    - [x] `pt-BR` Portuguese (Brazil)
    - [ ] `ru` Russian
    - [ ] `sl` Slovenian
    - [ ] `sv` Swedish
    - [ ] `th` Thai
    - [ ] `tr` Turkish
    - [ ] `uk` Ukrainian
    - [ ] `vi` Vietnamese
    - [x] `zh-Hans` Chinese (Simplified)
    - [x] `zh-Hant` Chinese (Traditional, current app locale: `zh-Hant-TW`)

    </details>

## Screenshots

<p align="center">
  <img src="docs/登录en.png" alt="Login" width="24%">
  <img src="docs/首页en.png" alt="Home" width="24%">
  <img src="docs/导航栏en.png" alt="Navigation" width="24%">
  <img src="docs/设置en.png" alt="Settings" width="24%">
</p>

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=hzc073/memoflow&type=Date)](https://www.star-history.com/#hzc073/memoflow&Date)

# Acknowledgments
- [Memos](https://github.com/usememos/memos)
- [MoeMemos](https://github.com/mudkipme/MoeMemos)
