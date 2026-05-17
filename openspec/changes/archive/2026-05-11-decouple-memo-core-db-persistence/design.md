## Context

The recent DB persistence extractions moved specialized tables out of `AppDatabase`, but the facade still owns core memo schema:

- `CREATE TABLE IF NOT EXISTS memos`
- `CREATE TABLE IF NOT EXISTS attachments`
- historical `ALTER TABLE memos ADD COLUMN ...` migrations
- `display_time` backfill
- raw memo count SQL

`AppDatabaseWriteDao` also still contains one legacy `attachments` table-local primitive used when renaming memo UIDs.

## Decisions

### Decision 1: Extract schema and migration helpers only

`MemoCoreDbPersistence` owns:

- `ensureMemoTable`
- `ensureAttachmentTable`
- `ensureRelationCountColumn`
- `ensureLocationColumns`
- `ensureDisplayTimeColumnAndBackfill`
- `countMemos`
- `renameAttachmentMemoUid`

This keeps table-level DDL and small table-local primitives out of the facade without moving the larger memo write workflow yet.

### Decision 2: Preserve lifecycle and transaction ownership

`AppDatabase` still controls database lifecycle order in `onCreate`, `onUpgrade`, and `onOpen`.

`AppDatabaseWriteDao` still owns memo write transactions, FTS refresh orchestration, tag mapping updates, stats deltas, outbox coordination, and memo lifecycle side effects.

### Decision 3: Keep the legacy `attachments` table with core memo persistence

The `attachments` table is currently created by `AppDatabase` and only has a memo-UID rename primitive in the DAO. Because it is keyed by memo ownership and is not the JSON attachment list stored on `memos.attachments_json`, this change keeps it with `MemoCoreDbPersistence` instead of creating a broader attachment repository.

## Dependency Direction

Before:

```text
AppDatabase -> memos/attachments schema SQL + column migration SQL + count SQL
AppDatabaseWriteDao -> attachments table-local update SQL
```

After:

```text
AppDatabase -> lifecycle delegation -> MemoCoreDbPersistence
AppDatabaseWriteDao -> memo write orchestration -> MemoCoreDbPersistence for legacy attachment rename
MemoCoreDbPersistence -> sqflite only
```

This does not add new `state -> features`, `application -> features`, or `core -> higher layer` imports.

## Risks

- Migration behavior must stay compatible for old DB versions that are missing `relation_count`, location columns, or `display_time`.
- `display_time` backfill must still run after the column exists.
- The full memo write path remains coupled by design; this change only removes schema and small table-local primitives.
