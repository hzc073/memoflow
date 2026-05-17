## Context

当前 RSS MVP 的数据边界是正确的：

```text
rss_feeds -> rss_articles -> CollectionReadableItem
```

但用户入口仍然偏向 memo collection：

```text
create manual collection
        |
        v
open reader overflow
        |
        v
add RSS feed
```

这个流程会让 RSS 被理解成 manual collection 的附加源。现在明确的新产品语义是：

```text
RSS collection = RSS feeds only
RSS article    = can be explicitly saved as memo
```

## Goals / Non-Goals

**Goals:**

- RSS collection 成为 collection creation flow 中的一等类型。
- 一个 RSS collection 可以订阅多个 RSS/Atom feeds。
- RSS collection 不包含 smart memo rules，也不包含 manual memo membership。
- RSS article 的 save-as-memo 入口比 overflow 更明显。
- Saved memo 仍然是普通 memo，RSS article 仍然保留在 RSS-owned state。

**Non-Goals:**

- 不把 RSS articles 自动写入 `memos`。
- 不让 RSS collection 混入 memo items。
- 不在本 change 中实现 OPML、后台刷新、通知、full-content fetch。
- 不改 Memos server API。

## Proposed Shape

### 1. Dedicated collection type

Preferred model:

```text
MemoCollectionType
  smart
  manual
  rss
```

Behavior:

```text
smart  -> CollectionRuleSet -> LocalMemo[]
manual -> memo_collection_items -> LocalMemo[]
rss    -> collection_rss_sources -> RssArticleWithFeed[]
```

RSS collection should use the existing `collection_rss_sources` table for feed associations. RSS-specific persistence stays in RSS-owned tables:

```text
memo_collections(type = rss)
collection_rss_sources(collection_id, feed_id)
rss_feeds
rss_articles
```

Avoid modeling RSS as "manual collection with no manual items". That would keep leaking manual labels, manual empty-state prompts, and memo-management actions into RSS surfaces.

### 2. Creation flow

Create collection entry should expose three choices:

```text
Smart collection
Manual collection
RSS collection
```

RSS creation path:

```text
choose RSS collection
        |
        v
enter feed/site URL
        |
        v
discover/parse + preview
        |
        v
add feed to draft list
        |
        v
optionally add more feeds
        |
        v
save RSS collection
```

The first feed can provide default title/icon hints:

```text
collection title empty -> use first feed display title
collection icon default -> rss_feed icon
collection color default -> normal collection default or RSS accent
```

Creation should require at least one valid feed. Additional feeds can be added in the creation flow and later through RSS collection source management.

### 3. RSS-only behavior

RSS collections should not show smart-rule controls or manual memo picker controls. They should also not appear as valid targets in "add memo to collection" flows.

Dashboard/list presentation should distinguish the type:

```text
Smart   -> auto_awesome
Manual  -> playlist_add_check / collections_bookmark
RSS     -> rss_feed
```

Filters should either add an RSS filter or otherwise make RSS collections discoverable without being lumped under manual.

### 4. Multi-feed article composition

RSS collection article resolution should use all attached feeds:

```text
collection_rss_sources
        |
        v
rss_articles for all feed_id values
        |
        v
CollectionReadableItem[]
```

Sorting can reuse existing collection sort preferences where meaningful, but RSS collections should default to newest article first:

```text
default sort = displayTimeDesc
```

Manual-order sorting is not a good default for RSS-only collections because articles arrive over time and feeds are source-owned.

### 5. Prominent save-as-memo shortcut

Current path is too deep:

```text
reader -> overflow -> current item actions -> save as memo
```

Preferred shortcuts:

```text
RSS article row/card       -> bookmark/save icon
RSS reader current article -> toolbar save icon or labeled action
overflow menu             -> keep existing fallback action
```

State:

```text
not saved -> Save as memo
saved     -> Saved as memo / open saved memo if a safe route exists
```

The action must remain article-scoped. It should never save all articles in a feed or collection.

### 6. Dependency direction / modularity

Keep ownership clear:

```text
features/collections
  -> state/collections
  -> data/repositories

application/rss
  -> data/repositories/rss_repository
```

Avoid:

```text
data/application/state -X-> features/collections
RSS parser/fetcher     -X-> collection widgets
```

Collection type predicates and RSS-only source behavior should be centralized enough that widgets do not each reinvent "is this RSS-only?" decisions.

## Risks / Trade-offs

- [Risk] Adding `MemoCollectionType.rss` touches many switch statements. Mitigation: keep the change scoped, add exhaustive tests, and centralize labels/icons/type behavior.
- [Risk] Existing manual collection code may assume non-smart means manual. Mitigation: explicitly audit type checks and update filters, editor validation, add-to-collection flows, and resolver behavior.
- [Risk] RSS collection creation could duplicate subscription logic. Mitigation: reuse existing RSS preview/subscription services and keep feed write paths in repository/state seams.
- [Risk] A visible save button may be interpreted as saving the whole feed. Mitigation: place it on article-scoped surfaces and use labels/tooltips that refer to the current article.

## Resolved Decisions

- RSS collections are RSS-only and SHALL NOT contain manual memo items or smart memo results.
- RSS collections MAY contain multiple feeds.
- RSS article save-as-memo remains explicit and per-article.
- The save-as-memo shortcut should be more visible than the overflow-only path.
