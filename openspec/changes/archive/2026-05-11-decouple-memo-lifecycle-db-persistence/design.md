## Context

The lifecycle persistence surface is currently split:

- `AppDatabase` owns schema creation and several read/query helpers for lifecycle tables.
- `AppDatabaseWriteDao` owns lifecycle writes, memo delete flows, and memo renaming that touches lifecycle tables.

That works but keeps lifecycle table SQL coupled to the DB facade instead of a focused persistence owner.

## Decisions

### Decision 1: Extract lifecycle table-local SQL into `MemoLifecycleDbPersistence`

`MemoLifecycleDbPersistence` will own:

- `ensureTables`
- `list/get/delete` helpers for `memo_versions`, `recycle_bin_items`, `memo_delete_tombstones`, `memo_relations_cache`, and `memo_inline_image_sources`
- table-local insert/update/delete primitives that accept `DatabaseExecutor`
- row mapping helpers where they are needed for those tables

### Decision 2: Preserve lifecycle and transaction ownership

`AppDatabase` will still control when lifecycle table setup runs from `onCreate` / `onUpgrade` / `onOpen`.

`AppDatabaseWriteDao` will still own transaction boundaries and notification policy. The extracted persistence owner must not call `.transaction(`.

### Decision 3: Keep memo-core coupling out of scope

This change does not extract the main `memos` table. It only extracts the lifecycle support tables around memo versions, recycle bin, tombstones, relations cache, and inline image sources.

## Dependency Direction

Before:

```text
AppDatabase -> lifecycle table SQL + lifecycle reads
AppDatabaseWriteDao -> lifecycle writes + mixed memo lifecycle orchestration
```

After:

```text
AppDatabase -> lifecycle/facade delegation to MemoLifecycleDbPersistence
AppDatabaseWriteDao -> transaction/notify + lifecycle orchestration
MemoLifecycleDbPersistence -> sqflite + data-layer models only
```

This should not add new `state -> features`, `application -> features`, or `core -> higher layer` imports.

## Risks

- Memo delete flows are mixed writes that touch outbox and memo tables. Keep transaction ownership in the DAO and only extract table-local lifecycle primitives.
- Migration ordering must stay stable. Preserve the existing upgrade sequence while moving the implementation behind a seam.
- Recycle bin and tombstone helpers are user-visible through timeline and sync flows; keep row ordering and state codes unchanged.
