## 1. Database search index foundations

- [x] 1.1 Add `memo_search_documents`, `memo_search_substrings`, and dirty-marker schema/migration support in `memos_flutter_app/lib/data/db/app_database.dart`
- [x] 1.2 Implement canonical search-document, 1-char/2-char gram generation, and memo-scoped rebuild/delete helpers in `memos_flutter_app/lib/data/db/app_database.dart`
- [x] 1.3 Add dirty-queue enqueue/drain logic and correctness fallback for still-dirty memos so incremental invalidation does not require a full backfill

## 2. Search coordination rollout

- [x] 2.1 Introduce `SearchCoordinator` query/result orchestration and shared normalization/verification helpers under `memos_flutter_app/lib/state/memos/`
- [x] 2.2 Route main memo search and local/offline search through `SearchCoordinator` while preserving state/tag/date/advanced-filter behavior
- [x] 2.3 Route shortcut search, quick search, and link-memo lookup through `SearchCoordinator` and remove duplicated remote/local merge logic

## 3. Verification

- [x] 3.1 Add database-focused tests for CJK middle-substring lookup, searchable metadata hits, and memo-scoped incremental invalidation
- [x] 3.2 Add state/search-flow tests covering remote false-positive filtering, local supplement of remote misses, and dirty-index fallback correctness
- [x] 3.3 Run `flutter test` for affected search suites and `flutter analyze` in `memos_flutter_app`; if API search request behavior changes, also run `flutter test test/data/api --reporter expanded`
