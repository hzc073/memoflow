## Context

`AppDatabase` currently owns both database orchestration and memo search implementation details. The search-related responsibilities include:

```text
AppDatabase
  -> public listMemos/watchMemos facade
  -> canonical search-document construction
  -> SQLite FTS table creation/recovery/backfill
  -> memo_search_documents / memo_search_substrings / memo_search_dirty
  -> dirty-entry drain and merge fallback
  -> memo write hooks that update FTS and dirty index state
```

The active architecture phase is `evolve_modularity`. This change touches modularity checklist items `7`, `8`, and `10` by giving memo search persistence a clearer data-layer owner and adding guardrails that prevent the touched area from drifting back into `AppDatabase` or higher layers.

Current dependency shape:

```text
state/memos search code
  -> AppDatabase.buildCanonicalMemoSearchDocument
  -> AppDatabase.listMemos/watchMemos

AppDatabase
  -> core MemoSearchMatcher
  -> core tags
  -> memo search SQL/index helpers inline
```

Target first step:

```text
state/memos search code
  -> MemoSearchDocumentBuilder or equivalent pure seam
  -> AppDatabase.listMemos/watchMemos facade

AppDatabase
  -> MemoSearchDbPersistence
  -> MemoSearchDocumentBuilder

MemoSearchDbPersistence
  -> sqflite
  -> lower-level search/tag helpers only
```

## Goals / Non-Goals

**Goals:**

- Move pure canonical search-document construction out of `AppDatabase`.
- Move memo search SQLite table/index/rebuild/dirty-drain helpers out of `AppDatabase` into focused data-layer persistence file(s).
- Preserve the existing `AppDatabase.listMemos`, `AppDatabase.watchMemos`, `buildMemoSearchDocumentForMemo`, and `buildCanonicalMemoSearchDocumentForMemo` public behavior during this extraction, unless a direct static helper can be replaced by a pure seam without changing callers' behavior.
- Preserve local search semantics: literal substring matching, CJK middle substring support, literal `LIKE` handling, searchable tag and clip-card metadata, filter constraints, ordering, limits, and partial dirty-index correctness.
- Preserve existing memo write behavior, desktop write proxy behavior, and notification behavior.
- Add or tighten architecture guardrails around the extracted memo search seams.

**Non-Goals:**

- Do not change user-facing memo search behavior.
- Do not change server API compatibility or remote search request semantics.
- Do not replace the current substring index algorithm with a different search engine.
- Do not remove `AppDatabase.listMemos` or `AppDatabase.watchMemos` in this change.
- Do not refactor outbox, stats cache, AI semantic search, tag repository ownership, or collection persistence beyond the calls needed to preserve memo search indexing.
- Do not attempt an architecture phase transition.

## Decisions

### Decision: Extract pure search-document construction first

Move `buildMemoSearchDocument` and `buildCanonicalMemoSearchDocument` logic to a lower-level pure helper such as `MemoSearchDocumentBuilder`.

This addresses a real boundary smell: state/search code currently imports `AppDatabase` to construct a canonical search document for in-memory remote normalization. That operation does not require a database connection and should not depend on the database facade.

Before:

```text
state/memos -> AppDatabase static helper -> canonical text
```

After:

```text
state/memos -> MemoSearchDocumentBuilder -> canonical text
AppDatabase -> MemoSearchDocumentBuilder -> canonical text
```

Alternative considered: leave static helper forwarding methods on `AppDatabase` indefinitely. Rejected as the end state because it keeps a pure search contract hidden behind the DB facade. A temporary forwarding method is acceptable only to keep the first patch small.

### Decision: Preserve `AppDatabase` search facades while moving SQL ownership

Keep `listMemos` and `watchMemos` on `AppDatabase` for this change. Internally, move search-index helpers to `MemoSearchDbPersistence` or similarly named focused files.

This mirrors the already completed compose draft extraction:

```text
Before callers: state/search -> AppDatabase
After callers:  state/search -> AppDatabase

Before internals: AppDatabase owns memo search SQL
After internals:  AppDatabase delegates memo search SQL/index helpers
```

Alternative considered: introduce a full `MemoSearchRepository` and migrate all callers in the same change. Rejected for this step because it would combine SQL extraction with provider/caller migration and make regressions harder to localize.

### Decision: Keep the current indexed search algorithm and row-map boundary

The new persistence owner should preserve the current `memo_search_documents`, `memo_search_substrings`, and `memo_search_dirty` behavior. It may expose row-map query helpers used by `AppDatabase.listMemos`, but should not introduce new model conversion ownership.

This keeps the compatibility boundary stable for:

- `LocalMemo.fromDb`
- remote search local fallback and normalization
- existing `app_database_search_test.dart`
- migration tests that inspect `memos_fts` recovery behavior

Alternative considered: rewrite `listMemos` around a typed search result model. Rejected because the goal is persistence extraction, not search API redesign.

### Decision: Keep DB lifecycle and migration ordering in `AppDatabase`

`AppDatabase` should continue to own:

- `_dbVersion`
- `openDatabase`
- `onCreate`, `onUpgrade`, and `onOpen` ordering
- desktop write proxy and local write envelope execution
- change notifications

The extracted persistence owner should own:

- search table creation SQL
- `memos_fts` creation/recovery/backfill helpers
- `memo_search_*` table creation and rebuild helpers
- mark/replace/delete/drain helpers for indexed search state
- helper query functions needed by `listMemos`

Alternative considered: move migration dispatch into a schema registry now. Rejected because that is a broader database architecture change and would touch many unrelated table owners.

### Decision: Add targeted guardrails instead of file-length targets

Success should be measured by ownership and dependency direction, not by an arbitrary line count. Guardrails should verify:

- memo search persistence files do not import `features/`, `state/`, or `application/`
- state/search code does not call pure canonical search-document rules through `AppDatabase`
- extracted memo search files stay in data/core seams and avoid new reverse dependencies

Alternative considered: add a strict maximum line count for `app_database.dart`. Rejected because it encourages mechanical movement without proving a better boundary.

## Risks / Trade-offs

- [Risk] Search results can subtly change because query constraints are spread across indexed rows, dirty rows, fallback matching, and merge sorting. -> Mitigation: keep facade behavior stable and run focused local search, dirty-index, and remote-normalization tests.
- [Risk] `memos_fts` recovery logic can regress on old or partially broken databases. -> Mitigation: keep existing migration tests in scope and avoid changing the recovery algorithm during extraction.
- [Risk] Dirty index draining can stop returning correct results while backlog remains pending. -> Mitigation: preserve dirty-row fallback query and merge behavior as part of the extracted owner.
- [Risk] Moving pure search-document construction can create duplicate normalization rules. -> Mitigation: use one shared helper consumed by both `AppDatabase` and state/search code.
- [Risk] The extracted persistence file could become another large mixed-responsibility file. -> Mitigation: allow a small split if needed, for example `memo_search_document_builder.dart` plus `memo_search_db_persistence.dart`, but avoid broad repository redesign.

## Migration Plan

1. Add the pure canonical search-document helper in a lower-level seam.
2. Replace state/search references to `AppDatabase.buildCanonicalMemoSearchDocument` with that helper.
3. Add memo search DB persistence file(s) and move table/index/rebuild/dirty helper logic into them.
4. Update `AppDatabase` to delegate search helper calls while preserving public facade signatures and migration/open ordering.
5. Add focused architecture guardrails for the new seams.
6. Run focused memo search, migration, architecture, analyze, and broader tests.

Rollback is straightforward if facade signatures stay stable: re-inline delegation calls in `AppDatabase` without changing external callers or schema.

## Open Questions

- Should `memos_fts` legacy recovery live in the same `MemoSearchDbPersistence` file as the substring index, or should it be split if the file becomes noisy?
- Should temporary `AppDatabase.buildCanonicalMemoSearchDocument` forwarding remain for compatibility during the first patch, or should all known callers migrate immediately?
- Are there additional remote-normalization tests that should be run beyond the existing memo search and coordinator coverage?
