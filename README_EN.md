# MemoFlow

<p align="center">
  <img src="docs/memoflow-logo.png" alt="MemoFlow Logo" width="120">
</p>

Chinese version: [README.md](README.md)
Official website: [memoflow.hzc073.com](https://memoflow.hzc073.com/) | Help Center: [memoflow.hzc073.com/help/](https://memoflow.hzc073.com/help/)

MemoFlow is a Flutter mobile client for the [memos](https://github.com/usememos/memos) backend. This project is an independent
third-party client and has no affiliation with the official Memos project.

## Features
- Offline-first: local SQLite cache + outbox retry queue.
- Create, edit, search, pin, archive, and delete memos with Markdown, tags, and task lists.
- Quick input: draft saving, tag suggestions, backlinks, attachments, camera capture, and undo/redo.
- Attachment browsing: image preview, audio playback, and voice memo recording.
- Random review and local statistics (monthly charts/heatmap), with sharing.
- AI summary reports with configurable provider/model/prompt; share a poster or save as a memo.
- Multi-account PAT login with compatibility mode for legacy Memos servers.
- Widgets, app lock, preferences (theme/language/fonts), and Markdown+ZIP export.

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
    - [ ] LaTeX formulas
  - Attachments
    - [x] Browse attachments
    - [x] Image preview
    - [x] Audio playback
    - [ ] Edit attachments
  - Interaction
    - [x] Likes/comments
- Other
  - [x] Offline-first sync
  - [ ] Single-device mode
  - [x] AI summary
  - [ ] Speech-to-text
  - [ ] Custom quick tools
  - [x] Task progress bar
  - [ ] Multi-language (align with Memos backend locales, 33 total)
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
    - [ ] `pt-BR` Portuguese (Brazil)
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
[Memos](https://github.com/usememos/memos)
