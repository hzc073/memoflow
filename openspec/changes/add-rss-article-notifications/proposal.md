## Why

Once RSS feeds can refresh automatically, users may want selected feeds to notify them about new articles. Notifications should be a separate change because they depend on reliable article ingestion and scheduling, and they introduce routing, dedupe, permissions, and user attention concerns.

## What Changes

- Add opt-in RSS article notifications for selected feeds or collection RSS sources.
- Notify only for newly ingested articles from enabled feeds.
- Deduplicate notification delivery across refresh runs.
- Route notification taps to the relevant RSS article in its collection context.
- Respect existing app notification permission behavior and quiet failure handling.

## Capabilities

### New Capabilities

- `collection-rss-notifications`: Defines opt-in RSS new-article notification behavior, dedupe, tap routing, and permission handling.

### Dependencies

- Depends on `add-rss-collection-mvp`.
- Strongly prefers `add-rss-background-refresh` because notifications are most valuable when new articles arrive from scheduled refresh.

## Impact

- Affected runtime area: RSS feed settings, refresh result reporting, notification scheduling/presentation, app startup notification routing, and collection article opening.
- No Memos server API route, request/response model, version adapter, or `memos_flutter_app/lib/data/api` change is intended.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 6 (routing via seams), item 7 (notification delivery state owner), item 8 (routing/dedupe guardrails), and item 10.

## Non-Goals

- Do not add background refresh itself.
- Do not notify for articles from feeds that are not explicitly enabled.
- Do not convert notified RSS articles into memos.
- Do not implement push notifications or server-side notifications.
- Do not fetch full content as part of notification delivery.
