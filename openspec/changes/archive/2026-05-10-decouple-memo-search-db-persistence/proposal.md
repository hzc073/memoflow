## Why

`AppDatabase` is still a persistence hotspot after compose draft extraction: it owns SQLite lifecycle, public memo search facades, `SQLite FTS` recovery, `memo_search_*` substring index maintenance, dirty-index draining, and pure canonical search-document construction. Memo search is a good next extraction target because its visible behavior is already covered by focused local search, dirty-index, and remote-normalization tests.

## What Changes

- Extract pure memo search document construction out of `AppDatabase` so state/search code does not depend on the database facade for non-SQL text matching rules.
- Extract memo search SQLite details into focused data-layer persistence owner(s), including `memos_fts`, `memo_search_documents`, `memo_search_substrings`, `memo_search_dirty`, index invalidation, rebuild, and dirty-drain helpers.
- Preserve existing `AppDatabase.listMemos`, `AppDatabase.watchMemos`, and related public search-facing methods as facade methods during this change.
- Preserve visible search semantics: literal substring matching, CJK middle substrings, `LIKE` literal escaping, searchable tags and clip-card metadata, dirty-entry fallback correctness, state/tag/date filters, ordering, and result limits.
- Preserve desktop write proxy and memo write behavior; this change should move search persistence ownership without changing remote API compatibility or user-facing search behavior.
- Add or tighten architecture guardrails so memo search persistence stays in the data layer and pure search-document rules are not exposed through `AppDatabase`.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `memo-search`: Clarify that memo search behavior must be preserved while its canonical search-document rules and SQLite search-index persistence are owned by narrower reusable seams instead of the monolithic `AppDatabase` class.

## Impact

- Active architecture phase: `evolve_modularity`.
- Modularity checklist items touched:
  - `7.` Touched write paths have clear owners such as services, repositories, or mutation seams.
  - `8.` Architecture guardrail tests protect the highest-risk dependency directions.
  - `10.` Changes touching coupled areas leave the touched area equal or better structured than before.
- Affected app areas:
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - New focused memo search persistence file(s) under `memos_flutter_app/lib/data/db/`
  - New or moved pure search document helper under a stable lower-level seam such as `memos_flutter_app/lib/core/` or `memos_flutter_app/lib/data/`
  - `memos_flutter_app/lib/state/memos/memos_search_providers.part.dart`
  - `memos_flutter_app/lib/state/memos/memo_search_coordinator.part.dart`
  - Architecture guardrails under `memos_flutter_app/test/architecture/`
  - Existing memo search, migration, architecture, and remote-normalization tests as verification targets
- No server API route/version changes are intended.
- No user-visible search behavior changes are intended.
- No database schema version change is intended unless implementation discovers an idempotency gap required to preserve existing search-index behavior.
