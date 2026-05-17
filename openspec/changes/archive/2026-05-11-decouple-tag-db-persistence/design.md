## Context

The current tag persistence surface is split informally:

- `AppDatabase` owns tag table schema, tag path resolution, `memo_tags` mapping, and migration backfill.
- `AppDatabaseWriteDao` owns tag mutations, transactions, notification, subtree path updates, aliases, and snapshot restore.
- `TagRepository` owns state-layer read SQL for `tags` and `tag_aliases` snapshots.

This matches existing behavior but keeps table-local SQLite details spread across the facade, DAO, and state layer.

## Decisions

### Decision 1: Extract table-local tag SQL into `TagDbPersistence`

`TagDbPersistence` will own:

- `ensureTables`
- `listTags`, `getTagByPath`, and `readSnapshot`
- `resolvePath`
- `updateMemoTagsMapping`
- `listMemoUidsByTagId(s)`
- `listTagPathsForMemo`
- focused helpers such as `loadTag`, `findResolvedTag`, `insertTagRow`, `insertAliasRow`, `deleteAllRowsForSnapshot`, `ensureUniqueName`, and `assertNoCycle`

Rationale: these are SQL/table primitives for `tags`, `tag_aliases`, and `memo_tags`. They can accept `DatabaseExecutor` from callers and do not need to own transactions.

### Decision 2: Preserve lifecycle and transaction owners

`AppDatabase` will still decide when tag table setup/backfill runs from `onCreate`/`onUpgrade`, and it will keep compatibility facade methods that delegate to `TagDbPersistence`.

`AppDatabaseWriteDao` will still own tag write transactions and `notifyDataChanged`. The extracted persistence owner must not call `.transaction(`.

### Decision 3: Move repository reads below state

`TagRepository` should not embed SQL for `tags` and `tag_aliases`; it should call `TagDbPersistence` with the opened database. This reduces state-layer knowledge of tag table layout without changing the repository public API.

## Dependency Direction

Before:

```text
state/tags -> AppDatabase/AppDatabaseWriteDao
state/tags -> direct tags/tag_aliases SQL
AppDatabase -> tag schema + tag mapping helpers
AppDatabaseWriteDao -> tag write SQL + transaction/notify
```

After:

```text
state/tags -> AppDatabase/AppDatabaseWriteDao -> TagDbPersistence
state/tags -> TagDbPersistence for read primitives
AppDatabase -> lifecycle/facade delegation to TagDbPersistence
AppDatabaseWriteDao -> transaction/notify + tag mutation orchestration
TagDbPersistence -> sqflite + core/data tag models only
```

This does not add new `state -> features`, `application -> features`, or `core -> higher layer` imports.

## Risks

- Snapshot restore and tag rename/delete flows update `memos.tags`, FTS, and stats cache through mixed write logic. Keep those mixed side effects in `AppDatabaseWriteDao` and only extract table-local tag primitives.
- Migration ordering must stay stable. Keep `AppDatabase` lifecycle call sites where they are and delegate implementation only.
- `AppDatabase` still has tag text and stats-cache logic for the core `memos.tags` column. This change targets the normalized tag tables, not the `tag_stats_cache` table.
