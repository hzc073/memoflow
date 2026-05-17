## Why

`db-persistence-boundaries` identifies Tags as the preferred next DB persistence extraction after compose draft, memo search, and outbox. The current tag tables are still partially owned by `AppDatabase`, while tag write orchestration lives in `AppDatabaseWriteDao` and repository reads still use direct table SQL.

The active architecture phase is `evolve_modularity`. This change touches checklist items 7, 8, 9, and 10 by clarifying the tag table owner, tightening guardrails, and leaving the touched DB write path better structured without changing API route/version behavior.

## What Changes

- Add `TagDbPersistence` under `memos_flutter_app/lib/data/db` as the owner for `tags`, `tag_aliases`, `memo_tags`, tag schema SQL, tag read queries, tag resolution, snapshot row primitives, and memo/tag mapping primitives.
- Keep `AppDatabase` as lifecycle/public facade owner and keep `AppDatabaseWriteDao` as transaction/notification owner.
- Move `TagRepository` read paths to the data-layer persistence seam instead of embedding tag table SQL in state code.
- Preserve existing public facade behavior, desktop write-proxy operation names, tag ordering, alias resolution, snapshot restore behavior, and memo tag text/search/cache side effects.
- Add/tighten architecture guardrails so focused DB persistence files stay lower-layer and `AppDatabase` does not re-own extracted tag SQL.

## Non-Goals

- No API route/version changes.
- No SQLite schema redesign or data migration version bump.
- No broad caller migration away from existing `AppDatabase` or `TagRepository` public surfaces.
- No change to `AppDatabaseWriteDao` transaction ownership or `notifyDataChanged` policy.

## Impact

- Runtime files:
  - `memos_flutter_app/lib/data/db/tag_db_persistence.dart`
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - `memos_flutter_app/lib/data/db/app_database_write_dao.dart`
  - `memos_flutter_app/lib/state/tags/tag_repository.dart`
- Tests/guardrails:
  - focused tag repository/core/db tests as applicable
  - architecture guardrails under `memos_flutter_app/test/architecture`
