## Why

`db-persistence-boundaries` marks memo lifecycle tables as the next batch after tags. The current lifecycle tables are still split between `AppDatabase` and `AppDatabaseWriteDao`, which keeps schema SQL and row primitives spread across the DB facade and the write owner.

The active architecture phase is `evolve_modularity`. This change touches checklist items 7, 8, 9, and 10 by tightening ownership for lifecycle persistence, adding guardrails, and leaving the touched DB area better structured without changing API or sync protocol behavior.

## What Changes

- Add `MemoLifecycleDbPersistence` under `memos_flutter_app/lib/data/db` for `memo_versions`, `recycle_bin_items`, `memo_delete_tombstones`, `memo_relations_cache`, and `memo_inline_image_sources`.
- Keep `AppDatabase` as lifecycle/public facade owner and keep `AppDatabaseWriteDao` as transaction/notification owner.
- Move lifecycle table schema SQL, read queries, and executor-level primitives out of `AppDatabase` and the write DAO where practical.
- Preserve public facade behavior, write-proxy operation names, memo version ordering, recycle bin ordering, tombstone state semantics, and notification behavior.
- Add/tighten architecture guardrails so focused DB persistence files stay lower-layer and `AppDatabase` does not re-own extracted lifecycle SQL.

## Non-Goals

- No API route/version changes.
- No schema redesign or version bump beyond what the existing lifecycle tables require.
- No broad caller migration away from existing `AppDatabase` write facade methods.
- No change to transaction ownership or `notifyDataChanged` policy.

## Impact

- Runtime files:
  - `memos_flutter_app/lib/data/db/memo_lifecycle_db_persistence.dart`
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - `memos_flutter_app/lib/data/db/app_database_write_dao.dart`
- Tests/guardrails:
  - focused lifecycle/db/architecture tests as applicable
