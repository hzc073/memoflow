## Why

`AppDatabase` still owns core memo table schema details after the smaller persistence extractions. It directly creates `memos`, creates the legacy `attachments` table, applies `ALTER TABLE memos` migrations, backfills `display_time`, and counts memo rows with raw SQL.

The active architecture phase is `evolve_modularity`. This change extracts core memo schema and small table-local primitives into a focused data-layer owner while keeping memo write orchestration in `AppDatabaseWriteDao`.

## What Changes

- Add `MemoCoreDbPersistence` under `memos_flutter_app/lib/data/db`.
- Move `memos` and legacy `attachments` schema setup out of `AppDatabase`.
- Move core memo column migration helpers and `display_time` backfill out of `AppDatabase`.
- Move `countMemos` SQL behind the new persistence owner.
- Move the legacy `attachments.memo_uid` rename primitive out of `AppDatabaseWriteDao`.
- Add guardrails so core memo schema SQL does not move back into `AppDatabase`.

## Non-Goals

- No API route/version changes.
- No schema redesign or database version bump.
- No change to memo write transaction ownership.
- No extraction of the full `memos` write path from `AppDatabaseWriteDao`.
- No change to desktop write-proxy operation names.

## Impact

- Runtime files:
  - `memos_flutter_app/lib/data/db/memo_core_db_persistence.dart`
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - `memos_flutter_app/lib/data/db/app_database_write_dao.dart`
- Tests/guardrails:
  - DB migration tests
  - memo write envelope tests
  - architecture guardrails
