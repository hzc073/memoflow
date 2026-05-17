## Context

Notification delivery should sit after ingestion:

```text
RSS refresh -> new rss_articles -> notification planner -> local notification
```

It should not change RSS article storage semantics and should not create memos.

## Goals / Non-Goals

**Goals:**

- Per-feed or per-collection-source notification opt-in.
- Notify only for newly discovered articles.
- Avoid duplicate notifications for the same article.
- Tap routes into the RSS article reading context.
- Permission failures are recoverable and visible where appropriate.

**Non-Goals:**

- No server push.
- No full-content fetch.
- No notification for every feed by default.

## Proposed Shape

### 1. Notification eligibility

Suggested state:

```text
rss_feeds.notification_enabled
rss_articles.notification_state or notification_delivered_time
```

Eligibility:

```text
newly inserted article
feed notification enabled
article has not been notified
app has notification permission
```

### 2. Notification planner

Keep notification decision logic separate from fetch parsing:

```text
RSS fetch service
  -> returns inserted article ids
RSS notification planner
  -> filters eligible articles
  -> schedules local notifications
  -> records delivered/skipped state
```

This lets manual refresh and scheduled refresh share notification behavior when the user opted in.

### 3. Tap routing

Notification payload should identify:

```text
rssArticleId
feedId
collectionId when known
```

If the feed belongs to multiple collections, prefer a deterministic collection context such as the source that triggered refresh or the first non-archived collection association.

### 4. User controls

Controls can appear in the RSS source/feed settings:

```text
Allow notifications
Notify for each new article or bundled summary
```

MVP for this change may use simple per-feed notifications or summary notifications, but must avoid duplicate delivery.

### 5. Dependency direction / modularity

Notification behavior should not live in collection widgets:

```text
application/rss/rss_article_notification_service.dart
  -> data/repositories/rss_repository.dart
  -> platform notification service
```

Collection UI should only read notification settings and call state/repository actions.

## Risks / Trade-offs

- [Risk] Too many notifications. Mitigation: opt-in, bundling option, and per-feed control.
- [Risk] Tap routing can break if collection was deleted. Mitigation: route to article detail fallback or show recoverable missing-context state.
- [Risk] Duplicate delivery after retries. Mitigation: durable delivered state on `rss_articles`.

## Resolved Decisions

- RSS notifications are opt-in.
- Notifications do not save articles as memos.
