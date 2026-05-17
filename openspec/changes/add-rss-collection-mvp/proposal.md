## Why

Collections are currently a curated way to revisit existing memos. RSS subscriptions add a different reading source: articles arrive from feeds and may be read inside a collection, but they should not automatically become memos. This preserves memo as an intentional user-authored or user-saved artifact, while letting collections become a broader reading shelf.

The MVP should establish the core boundary: RSS articles are independent collection reading content, and only become memos after an explicit "save as memo" action.

## What Changes

- Add local RSS subscription storage for feeds and articles.
- Allow a collection to include RSS feed sources without changing existing smart/manual memo semantics.
- Add a subscription flow that accepts a feed/site URL, discovers or parses a feed, previews metadata, and attaches the feed to a collection.
- Add manual refresh for subscribed RSS feeds.
- Show RSS articles as independent readable items in collection detail and reader surfaces.
- Add explicit "save as memo" for an RSS article, creating a normal memo and linking the article to the saved memo.
- Track basic RSS article state such as unread/read and saved memo linkage.

## Capabilities

### New Capabilities

- `collection-rss-subscriptions`: Defines RSS feed subscriptions as collection sources, RSS article ingestion, independent RSS reading items, and explicit article-to-memo saving.

### Modified Capabilities

- Existing collection behavior is extended by source composition only. Smart and manual memo collection behavior should remain compatible.

## Impact

- Affected app runtime area: `memos_flutter_app/lib/data/db`, `memos_flutter_app/lib/data/models`, `memos_flutter_app/lib/data/repositories`, `memos_flutter_app/lib/state/collections`, and `memos_flutter_app/lib/features/collections`.
- Affected reader seam: collection reader needs a stable readable-item abstraction so RSS articles do not masquerade as `LocalMemo`.
- Affected tests: new repository/parser tests, collection resolver tests, reader/action tests, and architecture guardrail coverage.
- No Memos server API route, request/response model, version adapter, or `memos_flutter_app/lib/data/api` change is intended.
- No subscription, billing, entitlement, receipt, paywall, StoreKit, or private-extension behavior.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 4 (avoid hiding reusable collection/RSS domain logic in widgets), item 6 (feature collaboration should use seams rather than direct screen coupling), item 7 (RSS write paths need repository/service ownership), item 8 (guardrails for persistence and boundaries), and item 10 (touched collection areas should be left equal or better structured).
- Modularity intent: introduce RSS as data/application owned services plus a collection readable-item seam, rather than adding RSS-specific branching throughout existing memo-only reader code.

## Non-Goals

- Do not automatically convert every RSS article into a memo.
- Do not sync RSS articles to the Memos server.
- Do not include RSS articles in memo export/local-library output unless they have been explicitly saved as memos.
- Do not add background scheduled refresh.
- Do not add RSS notifications.
- Do not add full-content extraction beyond feed-provided content.
- Do not add OPML import/export.
- Do not implement commercial/private-extension logic.
