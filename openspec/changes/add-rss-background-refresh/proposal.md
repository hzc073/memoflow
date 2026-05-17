## Why

After RSS subscriptions exist in collections, manual refresh alone can make feeds feel stale. However true OS-level background refresh adds platform scheduling complexity, possible permission prompts, native configuration, battery/network trade-offs, and extra surface area for a feature that not every user needs.

This change therefore narrows the scope to collection-open RSS refresh only: when the user opens an RSS collection, the app performs a delayed stale-feed check for that collection and refreshes only feeds that are due. The app does not refresh RSS globally on app launch/resume and does not keep a foreground-wide RSS timer running.

## What Changes

- Add configurable collection-open refresh for RSS feeds.
- Refresh feeds using RSS-owned services and repositories introduced by `add-rss-collection-mvp`.
- Track per-feed refresh status, last success, retryable failure, and collection-open refresh source.
- Trigger refresh from RSS collection entry only, after the collection surface is usable, without blocking navigation or initial rendering.
- Keep notifications out of this change; new articles are stored silently.
- Do not add platform background scheduling, background permissions, exact alarms, or native background task registration.
- Do not add app-wide startup/resume refresh or a global foreground RSS timer.

## Capabilities

### New Capabilities

- `collection-rss-open-refresh`: Defines collection-open RSS refresh behavior, refresh constraints, failure handling, and boundary requirements.

### Dependencies

- Depends on `add-rss-collection-mvp`.
- Should not be implemented before RSS feeds/articles and collection RSS sources exist.

## Impact

- Affected runtime area: RSS refresh service, RSS collection opening coordination, settings/preferences for refresh cadence, repository refresh metadata, and tests.
- No Memos server API route, request/response model, version adapter, or `memos_flutter_app/lib/data/api` change is intended.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 5 (composition roots should only schedule/cooperate), item 7 (refresh write path owner), item 8 (scheduler/boundary guardrails), and item 10.

## Non-Goals

- Do not add OS-level background refresh.
- Do not request background execution, exact alarm, battery optimization, or notification permissions for RSS refresh.
- Do not add new platform background scheduler dependencies such as `workmanager` or `background_fetch`.
- Do not refresh RSS globally when the app merely starts or resumes.
- Do not add a global foreground periodic RSS refresh timer.
- Do not add user-visible new-article notifications.
- Do not add new full-content extraction behavior beyond what existing manual feed refresh already performs.
- Do not add OPML import/export.
- Do not sync RSS articles to the Memos server.
- Do not make refresh timing exact or guaranteed.
