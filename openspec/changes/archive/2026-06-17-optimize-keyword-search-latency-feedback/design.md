## Context

MemoFlow currently maintains `memo_search_documents`, `memo_search_substrings`, and `memo_search_dirty`. `MemoSearchDbPersistence.listRows` can drain dirty entries during search, then scan remaining dirty rows with canonical Dart verification before merging them with indexed candidates.

Joplin 3.6.14 uses a different engine shape: `notes_normalized` plus `notes_fts`, with `item_changes` processed by `SearchEngine.syncTables()`. The useful rule for MemoFlow is not the exact FTS table choice; it is that index maintenance is treated as a background/explicit synchronization task instead of unbounded user-query work. Joplin's `queryBuilder` also shows the value of pushing filters into SQL before result hydration.

## Design Rules

### 1. Preserve MemoFlow search semantics

`MemoSearchMatcher` and `MemoSearchDocumentBuilder` remain the source of truth for visible keyword matching. Indexes, SQL constraints, or any future FTS path may narrow candidates only when they cannot exclude canonical matches.

Required visible behavior includes:

- literal substring matching
- 1-character and 2-character CJK queries
- tags in the canonical search document
- clip-card source name, author name, source URL, URL host, and host without `www.`
- literal treatment of `%`, `_`, FTS operators, server-filter syntax, and regex-like characters

### 2. Move dirty-index maintenance out of search

The user query path SHOULD be read-preferential. It MAY perform a small bounded correctness fallback, but it MUST NOT rely on unbounded `memo_search_dirty` scanning or index rebuilding before returning a first result set.

Preferred maintenance seams are:

- write-path follow-up after `markDirty`
- sync-completion maintenance
- app-idle maintenance
- explicit self-repair/rebuild actions
- startup/open maintenance with strict batching

Maintenance MUST be batched to avoid long write locks and SHOULD notify search watchers only when visible search results may change.

### 3. Keep dirty memos discoverable

Moving maintenance out of query time must not make freshly changed dirty memos invisible. Implementations MUST choose at least one bounded correctness strategy:

- eager background drain soon after writes
- bounded dirty fallback with a documented budget
- exact verification of a limited dirty subset selected by stable constraints
- explicit index-freshness status that prevents presenting incomplete results as complete

The rule is not "never inspect dirty rows"; the rule is "never let large dirty backlog size become unbounded synchronous search latency."

### 4. Push equivalent filters into SQLite

When a filter can be expressed equivalently in SQLite, it SHOULD be applied before Dart object construction. Good candidates include:

- `state`
- tag
- created/display date range already represented by DB time columns
- location presence
- location placeholder substring, when normalized equivalently
- attachment presence
- relation presence

Filters that depend on parsed attachment JSON, attachment category classification, shortcut parser behavior, or other Dart-only semantics MAY remain as Dart post-filters until an equivalent DB representation exists.

### 5. Keep Dart filtering as verification, not broad candidate selection

Dart filtering remains valid as a final verification layer, especially for advanced filters that are not safely expressible in SQL. However, when advanced filters are active, DB calls SHOULD use the strongest safe SQL constraints first so the app does not hydrate a broad memo set only to discard most rows.

### 6. Do not replace the engine with Joplin wholesale

This change MUST NOT replace MemoFlow's keyword search with a pure Joplin-style `SQLite FTS` path. Joplin's nonlatin behavior falls back to LIKE/basic search for CJK-like scripts, while MemoFlow's current unigram/bigram index better matches short CJK substring expectations.

Any future FTS migration MUST be a separate benchmarked design and MUST specify a hybrid fallback for short CJK queries unless equivalence is proven.

### 7. Preserve modular boundaries

Because the project is in `evolve_modularity`, future implementation MUST leave touched search areas equal or better structured:

- `data/db` owns search index tables, dirty backlog handling, and SQL candidate lookup
- `state/memos` may translate `AdvancedSearchFilters` into DB-owned query parameters
- `data/db` MUST NOT import `features/`, `state/`, or `application/`
- `state/memos` MUST NOT introduce `features/memos` imports
- UI code MUST NOT own search planning or dirty-index maintenance

## Alternatives Considered

- Full Joplin-style FTS replacement: rejected for this change because it risks reducing short CJK and arbitrary substring accuracy.
- Spinner-only improvement: out of scope for this narrowed rule update because the user asked to focus on background maintenance and SQL pushdown.
- Keep query-time dirty scanning unchanged: rejected because it preserves the main structural source of worst-case search latency.

## Verification Strategy For Future Implementation

- DB tests preserve CJK 1-character, CJK 2-character, middle substring, tag, clip metadata, URL host, and literal `%`/`_` behavior.
- Dirty backlog tests cover at least 0, 64, 500, and 2000 dirty rows and verify query-time work remains bounded.
- Advanced filter tests compare SQL-pushed candidate paths with existing Dart filter semantics.
- Architecture tests confirm no new `data/db -> state|features|application` or `state -> features` dependency is introduced.
