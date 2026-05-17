## Why

After extracting core memo schema, `AppDatabase` still owns several memo read/export SQL snippets. These are not lifecycle concerns; they are table-specific query primitives for `memos` and memo relation export joins.

The active architecture phase is `evolve_modularity`. This change moves memo query SQL into a focused data-layer owner while preserving the existing `AppDatabase` facade methods used by state and application layers.

## What Changes

- Add `MemoQueryDbPersistence` under `memos_flutter_app/lib/data/db`.
- Move memo read/export SQL out of `AppDatabase`.
- Move the tag snapshot memo-tag row read in `AppDatabaseWriteDao` behind the new query owner.
- Keep `AppDatabase` public method names and return shapes unchanged.
- Add guardrails so memo query SQL does not move back into `AppDatabase`.

## Non-Goals

- No API route/version changes.
- No database schema changes or version bump.
- No change to memo search behavior owned by `MemoSearchDbPersistence`.
- No extraction of the main memo write/upsert/delete workflow.
- No change to desktop write-proxy operation names.

## Impact

- Runtime files:
  - `memos_flutter_app/lib/data/db/memo_query_db_persistence.dart`
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - `memos_flutter_app/lib/data/db/app_database_write_dao.dart`
- Tests/guardrails:
  - memo search/query tests
  - local library/export related tests
  - architecture guardrails
