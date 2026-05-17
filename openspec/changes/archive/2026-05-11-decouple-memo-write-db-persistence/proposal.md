## Why

`AppDatabaseWriteDao` still owns table-local `memos` write primitives after the schema, query, search, lifecycle, auxiliary, stats, and core persistence extractions. The DAO should remain the write orchestrator, but direct row updates, inserts, deletes, and supporting row reads for the `memos` table can move behind a focused persistence owner.

The active architecture phase is `evolve_modularity`. This change leaves the touched write path better structured without changing API behavior, desktop write-proxy operation names, or transaction boundaries.

## What Changes

- Add `MemoWriteDbPersistence` under `memos_flutter_app/lib/data/db`.
- Move table-local `memos` row write primitives out of `AppDatabaseWriteDao`.
- Move `attachments_json` placeholder cleanup and memo row reads used by write-side FTS refresh behind focused persistence helpers.
- Keep memo write transaction orchestration, tag resolution/mapping, FTS refresh calls, stats delta application, lifecycle cleanup, outbox coordination, and notifications in `AppDatabaseWriteDao`.
- Add guardrails so `AppDatabaseWriteDao` does not re-own extracted `memos` table primitives.

## Non-Goals

- No API route/version changes.
- No schema redesign or database version bump.
- No change to memo write transaction ownership.
- No change to desktop write-proxy operation names or payloads.
- No movement of tag, FTS, stats, lifecycle, auxiliary, AI, collection, or outbox orchestration into the new persistence owner.

## Impact

- Runtime files:
  - `memos_flutter_app/lib/data/db/memo_write_db_persistence.dart`
  - `memos_flutter_app/lib/data/db/app_database_write_dao.dart`
- Tests/guardrails:
  - memo write/envelope tests
  - memo mutation/delete service tests
  - architecture guardrails
