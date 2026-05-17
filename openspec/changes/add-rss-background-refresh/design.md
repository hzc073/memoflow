## Context

The MVP provides manual RSS refresh:

```text
user action -> RSS fetch service -> rss_articles
```

This change adds collection-open refresh:

```text
user opens RSS collection
        |
        v
RSS refresh coordinator
        |
        v
same RSS fetch service and repository
```

## Goals / Non-Goals

**Goals:**

- Configurable collection-open refresh cadence.
- Refresh when the user opens an RSS collection and its feeds are stale.
- Delay the refresh trigger until the collection reading surface is usable, so navigation and initial rendering are not blocked.
- Refresh only feeds attached to the opened RSS collection.
- Preserve read state and saved memo linkage.
- Record refresh status and errors without blocking collection reading.
- Avoid RSS-specific platform permissions or native background task configuration.

**Non-Goals:**

- No OS-level background refresh.
- No background execution permission flow.
- No exact alarm, native background task, or platform scheduler integration.
- No app-wide startup/resume RSS refresh.
- No global foreground RSS refresh timer.
- No notification delivery.
- No new full-content extraction behavior beyond the existing manual feed refresh service.
- No OPML behavior.
- No exact refresh timing guarantee.

## Proposed Shape

### 1. Collection-open refresh coordinator

Introduce a coordinator that owns collection-open RSS refresh orchestration:

```text
application/rss/rss_refresh_coordinator.dart
  - receives the opened RSS collection id
  - loads feeds attached to that collection
  - decides which feeds are stale
  - limits refresh concurrency
  - calls RSS fetch service
  - records run status
```

The coordinator should reuse the MVP fetch service so manual and scheduled refresh share ingestion semantics.

### 2. Trigger source

Use a collection-open best-effort trigger:

```text
RSS collection route/surface opens
        |
        v
short delayed stale check
        |
        v
refresh stale feeds for that collection
```

The trigger should run after the collection screen has entered a usable state, for example after the first frame plus a short delay. It must not block opening the collection. Feeds may refresh later than the configured interval if the user does not open the collection; the next collection open should catch up stale feeds.

The implementation should explicitly avoid:

```text
app-wide RSS refresh on startup/resume
global foreground RSS timer
OS background job registration
background execution permission prompts
exact alarms
notification-based keepalive behavior
new background scheduler dependencies
```

### 3. Preferences and constraints

Refresh settings may include:

```text
enabled
interval
refresh_on_collection_open
```

The first implementation should prefer simple, user-understandable controls over a large scheduler settings page. Manual RSS refresh from the collection UI remains immediate and ignores the collection-open stale interval.

### 4. Failure behavior

Refresh failures should be feed-local and recoverable:

```text
rss_feeds.last_error
rss_feeds.last_fetch_time
rss_feeds.last_success_time
```

A failed feed should not prevent other feeds from refreshing.

### 5. Dependency direction / modularity

Keep scheduling and fetch ownership separated:

```text
features/collections
  -> collection-open trigger only
  -> RSS refresh coordinator
  -> RSS fetch service
  -> RSS repository
```

Avoid placing fetch loops or SQLite writes in UI widgets. Collection UI may trigger the coordinator but must not parse feeds, perform fetch loops, or write RSS SQLite primitives directly.
Also avoid placing platform background registration or permission logic in RSS UI surfaces, because this change intentionally does not own background execution.

## Risks / Trade-offs

- [Risk] Users may expect RSS to update as soon as the app opens. Mitigation: position this as collection-open refresh and keep manual refresh available for immediate user-triggered updates.
- [Risk] Collection-open refresh can still use network or battery while the user enters RSS. Mitigation: configurable cadence, stale checks, collection-scoped feed selection, and concurrency limits.
- [Risk] Multiple triggers may overlap. Mitigation: single-flight refresh guard and per-feed in-flight tracking.
- [Trade-off] Avoiding app-wide refresh keeps RSS work tied to actual RSS usage, but a feed will not update until the user opens an RSS collection or manually refreshes it.

## Resolved Decisions

- This change is collection-open only.
- This change stores new articles silently when an RSS collection is opened and stale feeds are refreshed.
- Notifications are intentionally deferred to `add-rss-article-notifications`.
- OS-level background refresh may be proposed later as a separate opt-in change if the product needs it.
