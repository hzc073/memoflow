## Why

RSS collection 目前已经具备 RSS-only 数据边界、RSS article 独立内容、full-content fetch、save-as-memo 等基础能力，但默认详情入口仍然沿用现有 `CollectionReaderShell`：打开 collection 后直接进入沉浸式连续阅读，把多篇 RSS articles 串成一本“合集/书”。

这对 memo/manual collection 是合理的，但不符合 RSS 的主要阅读习惯。RSS 更像文章流：先浏览多篇文章，再打开单篇阅读、标记已读、保存为 memo、抓取全文、跳到下一篇。参考项目 ReadYou 的价值主要在这个信息架构和交互习惯，而不是直接复刻代码或资源。

本 change 将为 RSS collection 引入 Memos 自己的 article flow reader，使 RSS 默认进入文章列表流，同时保留现有连续阅读器作为可切换阅读方式。后续书籍阅读类型也可以复用同一个 reading experience seam 扩展。

## What Changes

- Add collection-scoped reading experience preference:
  - RSS collection default: `articleFlow`
  - smart/manual collection default: existing continuous reader
  - user switching a collection reading experience persists to that collection
- Add RSS/default article flow surface:
  - article list with filters for all, unread, read, saved, feed, and date
  - list rows showing feed icon/name, title, excerpt, time, thumbnail, unread state, and saved state
  - built-in first-pass swipe actions for read/unread and save-as-memo
  - mark-above-as-read and mark-below-as-read actions
- Add single-article reading surface:
  - mobile opens a detail route
  - tablet/desktop uses a list-detail two-pane layout
  - opening an RSS article marks it read immediately
  - top actions: back, share, open original
  - bottom actions: read/unread toggle, save as memo, next article, full-content fetch/retry
  - no text-to-speech action in this change
  - no style entry in this change; reuse existing reader style preferences
- Add article-flow display settings:
  - show/hide excerpt
  - show/hide thumbnail
  - show/hide feed icon
  - compact/comfortable density
  - auto-hide single-article toolbar, default enabled
- Preserve the existing continuous reader and allow RSS collections to switch back to it.
- Allow smart/manual memo collections to switch into article-flow style list/detail reading, using memo-appropriate actions only.
- Add i18n strings for all touched user-facing labels.
- Add tests/guardrails so RSS flow logic stays outside lower layers and does not reintroduce memo or commercial/private leakage.

## Capabilities

### New Capabilities

- `collection-rss-flow-reader`: Defines collection reading experiences, RSS article-flow default behavior, single-article reading actions, list filters/display settings, progress separation, and architecture boundaries.

### Dependencies

- Depends on `add-rss-collection-mvp`.
- Depends on `add-rss-only-collection-type`.
- Uses `add-rss-full-content-fetch` behavior when full-content fetch state/actions exist.

### Related Changes

- `add-rss-opml-import-export`, `add-rss-background-refresh`, and `add-rss-article-notifications` are out of scope for this change.
- Future book-reader work can add another reading experience without changing RSS article ownership.

## Impact

- Affected runtime area: collection detail routing, collection model/view preference metadata, collection resolver/view state, RSS article list/detail UI, RSS article actions, device/collection preference persistence, localization, and tests.
- Affected reader seam: existing `CollectionReaderShell` should remain the continuous reader; new article-flow behavior should be separated enough that RSS-specific list/detail logic does not further enlarge the shell.
- Affected persistence: collection-scoped reading experience and article-flow display/progress state may require collection view metadata and/or local progress persistence.
- No Memos server API route, request/response model, version adapter, or `memos_flutter_app/lib/data/api` change is intended.
- No subscription, billing, entitlement, receipt, paywall, StoreKit, or private-extension behavior.
- No direct copying of GPLv3 ReadYou code, assets, or resources; ReadYou is used only as interaction/reference inspiration.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 4 (avoid hiding reusable reading-mode and RSS flow logic in widgets), item 6 (feature collaboration should use seams over direct screen coupling), item 7 (RSS article write paths continue through repositories/services), item 8 (guardrails for dependency direction and boundary leakage), and item 10 (touched collection areas should be left equal or better structured).
- Modularity intent: introduce a reading-experience routing seam and feature-local article-flow components rather than adding another RSS-specific branch throughout `CollectionReaderShell`.

## Non-Goals

- Do not implement OPML import/export.
- Do not implement background refresh.
- Do not implement notifications.
- Do not add text-to-speech.
- Do not add a dedicated style editing page for the new single-article surface.
- Do not add user-customizable swipe action mapping in the first implementation; only provide stable built-in defaults.
- Do not add RSS star/favorite state; saved-as-memo is the saved/starred equivalent.
- Do not automatically convert RSS articles into memos.
- Do not sync RSS articles to the Memos server.
- Do not copy GPLv3 ReadYou implementation code or assets.
