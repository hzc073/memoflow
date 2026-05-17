## Why

RSS MVP 已经证明了 feed/articles 可以作为 collection reading items 独立存在，但当前入口仍然让用户先创建 manual collection，再从 reader overflow 添加 RSS source。这个路径会让 RSS 看起来像 manual collection 的附属功能，也让 “save as memo” 入口过深。

产品语义需要更清晰：RSS collection 是一种只能由 RSS feeds 组成的 collection。用户可以在创建 collection 时直接选择 RSS 类型，订阅一个或多个 feeds，并在阅读单篇文章时更明显地保存为 memo。

## What Changes

- Add a dedicated RSS-only collection type alongside smart and manual collections.
- Let users create an RSS collection directly from the collection creation flow.
- Support one or more RSS feeds per RSS collection.
- Prevent RSS collections from using smart memo rules or manual memo item membership.
- Surface RSS collections distinctly in collection list/filter/detail/reader UI.
- Make single-article "save as memo" more visible from RSS article surfaces, while preserving the existing overflow action.
- Preserve the memo boundary: RSS articles still become memos only after explicit per-article action.

## Capabilities

### New Capabilities

- `collection-rss-only-collections`: Defines dedicated RSS-only collection creation, multi-feed source behavior, RSS-only memo boundary rules, and visible per-article save shortcuts.

### Dependencies

- Depends on `add-rss-collection-mvp`.
- Should be implemented after RSS feeds, RSS articles, collection RSS sources, and the collection readable-item seam exist.

### Related Changes

- `add-rss-opml-import-export` should map imported feeds into RSS collections when creating collection groups from OPML folders.
- `add-rss-background-refresh` and `add-rss-article-notifications` should treat RSS collections as normal collection contexts for RSS sources without creating memo content.
- `add-rss-full-content-fetch` should continue selecting readable RSS content independent from memo saving.

## Impact

- Affected runtime area: collection model/type metadata, collection creation/editor UI, collection list filters and labels, RSS subscription flow, collection resolver/dashboard preview behavior, RSS article list/reader actions, localization, and tests.
- Affected persistence: existing `memo_collections.type` handling may need a new `rss` enum value. RSS feed/article data should remain in RSS-owned tables.
- No Memos server API route, request/response model, version adapter, or `memos_flutter_app/lib/data/api` change is intended.
- No subscription, billing, entitlement, receipt, paywall, StoreKit, or private-extension behavior.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 4 (RSS-only behavior must not hide shared rules in widgets), item 6 (collection type/source collaboration should use seams), item 7 (RSS source write path owner), item 8 (guardrails for collection/RSS boundaries), and item 10.

## Non-Goals

- Do not allow RSS collections to contain manual memo items or smart memo rule results.
- Do not automatically convert RSS articles into memos.
- Do not sync RSS articles to the Memos server.
- Do not implement OPML import/export behavior in this change.
- Do not add background refresh, notifications, or full-content extraction.
- Do not remove the existing explicit overflow action for RSS article save-as-memo.
