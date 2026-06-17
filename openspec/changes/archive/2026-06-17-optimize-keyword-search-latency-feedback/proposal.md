## Why

GitHub issue #216 reports that keyword search over about 2000 memos can take more than 20 seconds. After comparing MemoFlow with Joplin 3.6.14, the most relevant lesson is not to replace MemoFlow search with Joplin's full FTS behavior, but to adopt two architectural rules:

- search index maintenance should move out of the user query path
- safe filters should be pushed down into SQLite before broad Dart filtering

MemoFlow's current keyword search intentionally supports canonical literal substring behavior, including 1-character and 2-character CJK queries. This behavior is stronger for short CJK substring search than Joplin's nonlatin fallback and MUST remain part of the visible search contract.

## What Changes

- Narrow this change to rules for background/explicit `memo_search_dirty` maintenance and SQL candidate reduction.
- Preserve existing keyword search semantics based on `MemoSearchMatcher` and `MemoSearchDocumentBuilder`.
- Require the user query path to avoid unbounded dirty-index rebuilds or full dirty backlog scans.
- Require equivalent SQL constraints to be applied before constructing broad `LocalMemo` lists for Dart filtering.
- Keep pure `SQLite FTS` / Joplin-style engine replacement out of scope unless a separate benchmarked proposal proves equivalent CJK and metadata behavior.
- Do not require application code changes in this rule-only step.

## Capabilities

### Modified Capabilities

- `memo-search`: Adds narrowed design rules for search-index maintenance and SQL filter pushdown while preserving canonical literal substring semantics.

## Impact

- Rule-only artifacts touched:
  - `openspec/changes/optimize-keyword-search-latency-feedback/proposal.md`
  - `openspec/changes/optimize-keyword-search-latency-feedback/design.md`
  - `openspec/changes/optimize-keyword-search-latency-feedback/tasks.md`
  - `openspec/changes/optimize-keyword-search-latency-feedback/specs/memo-search/spec.md`
- Future implementation may later touch:
  - `memos_flutter_app/lib/data/db/memo_search_db_persistence.dart`
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - `memos_flutter_app/lib/state/memos/memo_search_coordinator.part.dart`
  - `memos_flutter_app/lib/state/memos/memos_search_providers.part.dart`
- This rule update does not require editing API adapters or files under `memos_flutter_app/lib/data/api`.
