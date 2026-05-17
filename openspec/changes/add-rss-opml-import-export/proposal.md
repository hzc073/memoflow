## Why

Users with existing RSS setups often have OPML files from other readers. Once collections can subscribe to RSS feeds, import/export should be available as a separate change so the MVP can stay focused on subscriptions, reading, refresh, and save-as-memo behavior.

## What Changes

- Add OPML import for RSS subscriptions.
- Add OPML export for RSS feed subscriptions and grouping/collection organization.
- Preview import results before committing changes.
- Handle duplicates, malformed outlines, and partial import errors clearly.
- Keep OPML scoped to RSS subscription metadata; articles and memos are not imported or exported through OPML.

## Capabilities

### New Capabilities

- `collection-rss-opml`: Defines OPML import/export behavior, duplicate handling, grouping, preview, and memo-boundary rules.

### Dependencies

- Depends on `add-rss-collection-mvp`.
- Does not require background refresh, notifications, or full-content fetching.

## Impact

- Affected runtime area: RSS subscription import/export services, file picker/save integration, collection/feed mapping UI, parser/exporter tests, and architecture guardrails.
- No Memos server API route, request/response model, version adapter, or `memos_flutter_app/lib/data/api` change is intended.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 4 (OPML parser/exporter must be reusable service logic), item 7 (RSS subscription write path owner), item 8 (parser/import guardrails), and item 10.

## Non-Goals

- Do not import RSS articles from OPML.
- Do not export RSS articles or memos through OPML.
- Do not create memos during OPML import.
- Do not implement feed refresh itself.
- Do not require notification, scheduler, or full-content changes.
