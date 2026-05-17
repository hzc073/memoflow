## Context

Current collections resolve only `LocalMemo` items:

```text
MemoCollection
  smart  -> rules -> LocalMemo[]
  manual -> memo_collection_items -> LocalMemo[]
```

RSS introduces another source:

```text
RSS feed -> RSS articles -> collection reading surface
```

The important decision is that RSS articles are not memos by default. A user may explicitly save an RSS article into the memo system, but until then it stays in RSS-owned tables and state.

## Goals / Non-Goals

**Goals:**

- Users can subscribe a collection to one or more RSS/Atom feeds.
- Users can manually refresh RSS feeds.
- Feed items appear in collection detail and reader flows as independent readable content.
- RSS article read/unread state is stored separately from memo state.
- "Save as memo" creates a regular memo and links the RSS article to it.
- Existing smart/manual memo collections continue to behave as before.

**Non-Goals:**

- No automatic RSS-to-memo conversion.
- No background scheduler, notification, full-content fetch, or OPML behavior in this MVP.
- No Memos API compatibility change.

## Proposed Shape

### 1. Add RSS-owned persistence

Preferred table group:

```text
rss_feeds
  id
  feed_url
  site_url
  title
  description
  icon_url
  etag
  last_modified
  last_fetch_time
  last_success_time
  last_error
  created_time
  updated_time

rss_articles
  id
  feed_id
  guid
  link
  title
  author
  summary_html
  content_html
  lead_image_url
  published_time
  fetched_time
  read_state
  saved_memo_uid
  created_time
  updated_time

collection_rss_sources
  collection_id
  feed_id
  sort_order
  created_time
  updated_time
```

This keeps RSS lifecycle separate from memo lifecycle while allowing collections to reference feeds.

### 2. Introduce a readable-item seam

Collection UI and reader code should move away from assuming every item is a `LocalMemo`:

```text
CollectionReadableItem
  MemoCollectionReadableItem(LocalMemo)
  RssCollectionReadableItem(RssArticle, RssFeed)
```

The seam should expose only fields the reader needs:

```text
id
sourceKind: memo | rssArticle
title
subtitle/source label
content html or markdown-compatible body
published/display time
lead image / media references
savedMemoUid
```

Memo-specific actions such as pin, edit, and memo sync should remain available only for memo items. RSS-specific actions such as mark read/unread, open original, refresh feed, and save as memo should remain RSS-aware.

### 3. Subscription and manual refresh

MVP subscription flow:

```text
input feed or site URL
  -> normalize URL
  -> fetch XML, or discover feed link from HTML
  -> parse RSS/Atom metadata
  -> show preview
  -> attach feed to selected collection
```

Manual refresh:

```text
collection action or feed action
  -> fetch feed
  -> parse entries
  -> upsert articles by feed_id + guid/link
  -> keep local read state and saved_memo_uid
```

Parser behavior should support common RSS 2.0 and Atom feeds first. Feed discovery can be basic: HTML `<link rel="alternate" type="application/rss+xml|application/atom+xml">`.

### 4. Save as memo

Saving an RSS article should create a normal memo only on explicit user action:

```text
RssArticle
  title/content/source/link
      |
      v
MemoMutationService or existing memo creation seam
      |
      v
memos + memo_clip_cards
      |
      v
rss_articles.saved_memo_uid
```

The generated memo should include source attribution and original link. The `memo_clip_cards` metadata can represent the source site/feed so saved articles remain searchable through existing source-name/source-url search behavior.

### 5. Dependency direction / modularity

Current phase is `evolve_modularity`. The MVP should add stable ownership:

```text
data/db/rss_db_persistence.dart
data/models/rss_*.dart
data/repositories/rss_repository.dart
application/rss/rss_feed_fetch_service.dart
state/collections/rss providers
features/collections/rss UI adapters
```

The parser/fetcher must not live inside collection screen files. Lower layers must not import collection widgets or share capture widgets.

Avoid this:

```text
state/application/data  -X->  features/collections
state/application/data  -X->  features/share
```

Prefer this:

```text
features/collections -> state/collections -> data/repositories
application/rss      -> data/repositories
```

If any existing collection reader logic is extracted from widget files, place reusable pure logic in a stable feature-local or state/data seam depending on dependency needs.

## Risks / Trade-offs

- [Risk] Treating RSS articles as fake `LocalMemo` would make the MVP faster but leak memo-only actions and sync assumptions. Mitigation: introduce a readable-item seam.
- [Risk] Adding RSS sources to collections may expand collection complexity. Mitigation: keep smart/manual memo behavior intact and make RSS a source association rather than a new memo collection type.
- [Risk] Feed parsing can become broad quickly. Mitigation: MVP supports common RSS/Atom and clear failure states.
- [Risk] Saved memos could duplicate article content. Mitigation: link `saved_memo_uid` and make saved state visible.

## Resolved Decisions

- RSS articles SHALL remain independent collection reading content until explicitly saved.
- The MVP SHALL provide manual refresh only.
- Later background refresh, notification, full-content extraction, and OPML work SHALL be separate changes.
