## Why

`db-persistence-boundaries` lists collections as Batch 4 after tag, memo lifecycle, and AI extraction. `AppDatabase` still owns `memo_collections`, `memo_collection_items`, and `collection_read_progress` schema SQL, and `AppDatabaseWriteDao` still owns table-local reader-progress writes.

The active architecture phase is `evolve_modularity`. This change improves checklist items 7, 8, 9, and 10 by moving collection table-local SQLite details into a focused data-layer owner while preserving repository behavior, desktop write-proxy payloads, and notification policy.

## What Changes

- Add `CollectionDbPersistence` under `memos_flutter_app/lib/data/db`.
- Move collection schema/index setup for `memo_collections`, `memo_collection_items`, and `collection_read_progress` out of `AppDatabase`.
- Move `collection_read_progress` additive column helpers and row primitives out of `AppDatabase` and `AppDatabaseWriteDao`.
- Keep `AppDatabase` as lifecycle and desktop write-proxy facade owner.
- Keep `CollectionsRepository` as collection CRUD and logging owner.
- Keep `AppDatabaseWriteDao` as the approved write owner for reader-progress write proxy execution.
- Add/tighten architecture guardrails so `AppDatabase` and `AppDatabaseWriteDao` do not re-own extracted collection SQLite details.

## Non-Goals

- No collection UI behavior changes.
- No collection row shape or ordering changes.
- No desktop write-proxy operation or payload migration.
- No schema redesign or database version bump.
- No migration of `CollectionsRepository` collection CRUD logic in this step.

## Impact

- Runtime files:
  - `memos_flutter_app/lib/data/db/collection_db_persistence.dart`
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - `memos_flutter_app/lib/data/db/app_database_write_dao.dart`
- Tests/guardrails:
  - DB migration tests
  - collection repository/feature tests as applicable
  - architecture guardrails
