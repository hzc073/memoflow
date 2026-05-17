## Context

Current collection detail routing is effectively:

```text
CollectionDetailScreen
        |
        v
CollectionReaderScreen
        |
        v
CollectionReaderShell
  vertical / paged continuous reading
```

For RSS this creates a book-like reading experience:

```text
RSS collection
  Article A
  Article B
  Article C
        |
        v
continuous reader treats them like chapters
```

The desired RSS default is an article-flow experience:

```text
RSS collection
        |
        v
Article list / filters / feed grouping
        |
        v
Single article detail
        |
        v
read/unread, save as memo, full content, next article
```

ReadYou is a useful reference for this habit, especially flow -> reading detail, auto-hiding bars, next-article movement, and two-pane adaptive layout. The implementation should be Memos-native and should not copy ReadYou code/assets because the reference project is GPLv3.

## Goals / Non-Goals

**Goals:**

- RSS collection opens article flow by default.
- Users can switch a collection between article flow and the existing continuous reader, and the choice is saved per collection.
- Smart/manual memo collections can also use article-flow style list/detail reading, but with memo-appropriate actions only.
- RSS article detail supports read/unread toggle, save-as-memo, next article, full-content fetch/retry, share, and open original.
- Article list supports useful RSS filters and display settings.
- Progress for article flow and continuous reading stays separate.
- Reusable reading-mode routing and RSS flow logic does not become hidden inside large widget files.

**Non-Goals:**

- No OPML/background refresh/notification work.
- No TTS.
- No style page for the new article detail surface.
- No custom swipe action editor in the first version.
- No RSS star model.
- No direct ReadYou code/resource reuse.

## Proposed Shape

### 1. Reading experience seam

Introduce a collection-scoped reading experience concept:

```text
CollectionReadingExperience
  articleFlow
  continuousReader
  future: bookReader
```

Default resolution:

```text
collection.type == rss       -> articleFlow
collection.type == manual    -> continuousReader
collection.type == smart     -> continuousReader
saved collection preference  -> overrides default
```

Routing shape:

```text
CollectionDetailScreen
        |
        v
resolve collection + reading experience
        |
        +-- articleFlow      -> CollectionArticleFlowScreen
        |
        +-- continuousReader -> CollectionReaderScreen / CollectionReaderShell
```

The current reader should remain the owner of continuous reading behavior. The new article flow should not require expanding `CollectionReaderShell` with list/detail/feed filters.

### 2. Article flow model

Use existing readable item seam where possible:

```text
CollectionReadableItem
  MemoCollectionReadableItem
  RssCollectionReadableItem
```

Article flow should derive a UI model from readable items:

```text
ArticleFlowItem
  uid
  kind: memo | rssArticle
  sourceTitle
  sourceIcon
  title
  excerpt
  displayTime
  thumbnail
  unread
  saved
  originalUrl
```

RSS-specific fields come from `RssArticle` and `RssFeed`. Memo collections can still use the same list/detail shell, but actions are filtered:

```text
RSS article actions:
  mark read/unread
  save as memo
  fetch/retry full content
  open original
  share

Memo item actions:
  open memo/detail behavior
  share/copy/add-to-collection as applicable
  no full-content fetch
  no save-as-memo because it is already a memo
```

### 3. RSS filters and grouping

RSS article flow should support:

```text
status filter:
  all | unread | read | saved

feed filter:
  all feeds | specific feed

date grouping/filter:
  by date headers and/or selected date bucket
```

Sorting should follow collection view sort where meaningful, but RSS article flow should default to newest first.

The first version can use built-in swipe actions:

```text
one direction -> toggle read/unread
other direction -> save as memo
```

Custom swipe action mapping is intentionally deferred so the change does not become a settings-system project.

### 4. Single-article reading surface

Mobile:

```text
ArticleFlowScreen
        |
        v
tap row
        |
        v
ArticleDetailScreen
```

Tablet/desktop:

```text
┌──────────────────────┬──────────────────────────────┐
│ article list/filter  │ selected article detail       │
│ feed/date/status     │ top bar + content + bottom bar│
└──────────────────────┴──────────────────────────────┘
```

Article detail behavior:

```text
on open RSS article:
  mark article read immediately

top bar:
  back / close detail
  share
  open original

bottom bar:
  read/unread toggle
  save as memo
  next article in current list
  full-content fetch/retry
```

The detail body should reuse existing reader typography/style preferences, including font, text scale, line spacing, image behavior where applicable. It should not add a new style editor in this change.

Full-content failure or skipped state:

```text
show feed-provided content/summary
show recoverable status
allow retry when original link is available
allow opening original link
```

### 5. Progress separation

Do not overload the existing continuous reader progress with article-flow progress. Recommended model:

```text
collection reading preference:
  readingExperience
  articleFlowDisplayConfig

article flow progress:
  selectedStatusFilter
  selectedFeedId
  selectedDateBucket
  listScrollOffset
  currentItemUid

continuous reader progress:
  currentItemUid
  pageIndex
  listScrollOffset / chapter page

RSS article state:
  read/unread
  savedMemoUid
  fullContentStatus
```

This prevents switching between article flow and continuous reading from corrupting scroll/page restore behavior.

### 6. Display settings

Article-flow display settings should be collection scoped:

```text
showExcerpt: bool
showThumbnail: bool
showFeedIcon: bool
density: compact | comfortable
autoHideArticleToolbar: bool default true
```

These are list/detail presentation preferences, separate from article content style, which should reuse existing reader style preferences.

### 7. Dependency direction / modularity

Current desired direction remains:

```text
features/collections
  -> state/collections
  -> data/repositories

application/rss
  -> data/repositories/rss_repository
```

Avoid:

```text
state/application/data -X-> features/collections
RSS parser/fetcher     -X-> article-flow widgets
core                   -X-> state/application/features
```

Reusable logic should be placed according to dependency needs:

```text
data/models:
  durable preference/progress models if they are persisted

state/collections:
  providers/controllers for flow state and RSS actions

features/collections:
  widgets, adaptive layout, UI-only mapping

feature-local pure helpers:
  filter/sort/action availability logic if UI-only
```

Because the architecture phase is `evolve_modularity`, implementation should include at least one scoped improvement or guardrail, for example:

- Extract reading-experience routing decision into a small helper/model rather than embedding repeated type checks in screens.
- Add/tighten architecture tests that prevent `state/collections` or `application/rss` from importing collection widgets.
- Add tests that RSS article-flow actions do not auto-create memos except explicit save-as-memo.

## Risks / Trade-offs

- [Risk] Article flow could duplicate existing reader settings and progress concepts. Mitigation: separate article-flow display settings from shared content style preferences.
- [Risk] Adding list/detail behavior into `CollectionReaderShell` would make the current reader harder to maintain. Mitigation: keep article flow as a separate surface and route by reading experience.
- [Risk] Smart/manual memo collections in article flow could accidentally expose RSS-only actions. Mitigation: action availability must be item-kind aware and tested.
- [Risk] Full-content failure UI may expand scope. Mitigation: reuse existing RSS full-content statuses and provide simple fallback/retry/open-original behavior.
- [Risk] GPLv3 reference contamination. Mitigation: document that ReadYou is used for interaction inspiration only; do not copy code/assets/resources.

## Resolved Decisions

- RSS collection default reading experience SHALL be article flow.
- Existing `CollectionReaderShell` SHALL be preserved as continuous reader.
- Collection reading experience SHALL be saved per collection after user switching.
- RSS article opening SHALL mark that article read immediately.
- RSS saved/starred semantics SHALL use `savedMemoUid` / save-as-memo, not a new RSS star field.
- Single-article detail SHALL not include TTS or style entry in this change.
- First implementation SHALL include built-in swipe actions but not custom swipe mapping.
- Multi-language strings SHALL be added for user-facing labels.
