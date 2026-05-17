## Why

Many RSS feeds publish only excerpts. After RSS articles can appear as independent collection reading content, users will expect selected feeds or articles to provide a fuller reading experience without immediately becoming memos. Full-content fetching should be a separate change because it adds web-page fetching, extraction, sanitization, caching, and failure behavior beyond normal feed parsing.

## What Changes

- Add optional full-content fetching for RSS articles by using the article's original link.
- Allow users to enable full-content fetching per feed or request it manually per article.
- Store extracted content in RSS-owned article/content state.
- Prefer extracted full content in the RSS reader when available, with feed content as fallback.
- Preserve explicit "save as memo" behavior: fetched full content does not create a memo unless the user saves the article.

## Capabilities

### New Capabilities

- `collection-rss-full-content`: Defines full-content fetch, extraction, sanitization, fallback, and memo-boundary behavior for RSS articles.

### Dependencies

- Depends on `add-rss-collection-mvp`.
- Can integrate with `add-rss-background-refresh` if scheduled refresh exists, but it must not require background refresh.

## Impact

- Affected runtime area: RSS article model/persistence, RSS fetch/extraction services, article reader content selection, feed/article settings, and tests.
- No Memos server API route, request/response model, version adapter, or `memos_flutter_app/lib/data/api` change is intended.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 4 (shared extraction must not live in widgets), item 7 (RSS content write path owner), item 8 (sanitization/extraction guardrails), and item 10.

## Non-Goals

- Do not add RSS subscriptions or manual feed refresh; those belong to `add-rss-collection-mvp`.
- Do not add background scheduled refresh.
- Do not add notifications.
- Do not add OPML import/export.
- Do not auto-create memos from fetched full content.
- Do not bypass paywalls, authentication walls, or sites that cannot be safely fetched.
