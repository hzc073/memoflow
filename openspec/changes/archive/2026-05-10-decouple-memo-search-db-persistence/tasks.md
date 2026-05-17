## 1. Search Document Seam

- [x] 1.1 Identify all current `AppDatabase.buildMemoSearchDocument`, `AppDatabase.buildCanonicalMemoSearchDocument`, and related state/search call sites.
- [x] 1.2 Add a pure reusable memo search document helper under a stable lower-level seam, preserving content, tags, clip-card metadata, and canonical normalization behavior.
- [x] 1.3 Update `memos_search_providers.part.dart` and `memo_search_coordinator.part.dart` to use the pure helper instead of `AppDatabase` static search-document helpers.
- [x] 1.4 Keep any temporary `AppDatabase` forwarding methods only if needed for compatibility, and document the intended direction in code/tests through guardrail coverage.

## 2. Memo Search DB Persistence Extraction

- [x] 2.1 Identify all `memos_fts`, `memo_search_documents`, `memo_search_substrings`, and `memo_search_dirty` schema, recovery, rebuild, invalidation, drain, merge, and query helper code currently in `AppDatabase`.
- [x] 2.2 Add focused memo search persistence file(s) under `memos_flutter_app/lib/data/db/` for search table creation, `SQLite FTS` recovery/backfill, substring index creation, dirty-entry maintenance, and helper queries.
- [x] 2.3 Move `memos_fts` ensure/recovery/backfill helpers into the new persistence owner while preserving `onCreate`, `onUpgrade`, and `onOpen` ordering.
- [x] 2.4 Move `memo_search_*` ensure/rebuild/dirty-drain helpers into the new persistence owner while preserving incremental dirty backlog semantics.
- [x] 2.5 Move memo search row merge/sort and dirty-row fallback helpers only as far as needed to give the persistence owner clear responsibility without changing row-map outputs.

## 3. AppDatabase Facade Preservation

- [x] 3.1 Update `AppDatabase.listMemos` and `AppDatabase.watchMemos` internals to delegate search-specific SQLite/index work to the extracted owner while preserving public signatures and output rows.
- [x] 3.2 Update memo write/update/delete paths to call extracted search persistence helpers for FTS replacement, search dirty marking, index deletion, and searchable document rebuilds.
- [x] 3.3 Preserve desktop write proxy behavior and `notifyDataChanged` behavior for memo writes that affect search index state.
- [x] 3.4 Confirm no server API route/version compatibility files are touched by this change.

## 4. Guardrails

- [x] 4.1 Add or tighten an architecture guardrail proving memo search DB persistence files under `lib/data/db/` do not import `features/`, `state/`, or `application/`.
- [x] 4.2 Add or tighten a guardrail that fails if state/search code calls pure canonical search-document construction through `AppDatabase` instead of the reusable helper.
- [x] 4.3 Verify existing modularity allowlists are not expanded for `state -> features`, `application -> features`, or `core -> higher-layer` dependencies.

## 5. Focused Behavior Verification

- [x] 5.1 Run `flutter test test/data/db/app_database_search_test.dart` from `memos_flutter_app`.
- [x] 5.2 Run memo search consistency and remote-normalization focused tests that cover `MemoSearchCoordinator` and visible literal substring behavior.
- [x] 5.3 Run migration-focused tests covering legacy `memos_fts` recovery and `memo_search_*` table behavior.
- [x] 5.4 Run `flutter test test/architecture` from `memos_flutter_app`.

## 6. Final Verification

- [x] 6.1 Run `flutter analyze` from `memos_flutter_app`.
- [x] 6.2 Run `flutter test` from `memos_flutter_app`.
- [x] 6.3 Review the final diff to confirm `AppDatabase` no longer directly owns memo search document construction or search-index persistence details, and that visible memo search behavior remains unchanged.
