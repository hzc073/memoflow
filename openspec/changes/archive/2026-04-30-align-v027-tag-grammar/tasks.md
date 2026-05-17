## 1. Scope And Approval

- [x] 1.1 Confirm explicit user approval before editing API-related files under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api`
- [x] 1.2 Re-check the v0.27 backend tag grammar reference before implementation and note any newly discovered edge cases

## 2. Shared Tag Grammar

- [x] 2.1 Add focused `core/tags.dart` tests for `science&tech`, variation-selector or ZWJ emoji tags, hierarchical tags, protected URL fragments, and middle-line tags
- [x] 2.2 Update the shared tag validity and normalization logic in `core/tags.dart` to preserve v0.27-compatible characters
- [x] 2.3 Expand fallback extraction to scan all relevant memo content lines while preserving protected-fragment exclusions

## 3. V0.27 API And Sync Coverage

- [x] 3.1 Add v0.27 API compatibility coverage proving `ListMemos` non-empty `tags` arrays are exposed through the memo model/facade
- [x] 3.2 Add remote sync coverage proving backend-compatible v0.27 tags persist into `memos.tags`, `tags`, `memo_tags`, and `tag_stats_cache`
- [x] 3.3 Add fallback sync coverage proving a tag on a middle content line is persisted when backend `Memo.tags` is empty

## 4. Modularity Guardrails

- [x] 4.1 Verify tag grammar remains centralized in the shared `core/tags.dart` seam with no new parser duplication in feature screens or widgets
- [x] 4.2 Verify touched state/data code continues to depend downward on shared core helpers and does not introduce new `state -> features` or `application -> features` imports

## 5. Validation

- [x] 5.1 Run focused tag grammar tests from `memos_flutter_app`
- [x] 5.2 Run focused remote sync/state tests from `memos_flutter_app`
- [x] 5.3 Run `flutter test test/data/api --reporter expanded` after API compatibility test changes
