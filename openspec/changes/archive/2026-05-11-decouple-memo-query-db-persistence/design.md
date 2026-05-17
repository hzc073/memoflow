## Context

`AppDatabase` is now closer to a facade, but it still builds memo query clauses directly for:

- single memo lookup by `uid`
- tag string scans
- attachment-row scans
- memo sync-state scans
- export queries
- lossless export query with `memo_relations_cache`

These are table-specific read concerns and can be owned by a persistence helper without changing callers.

## Decisions

### Decision 1: Extract memo query primitives into one focused owner

`MemoQueryDbPersistence` owns:

- `getMemoByUid`
- `listTagStrings`
- `listMemoAttachmentRows`
- `listMemoUidSyncStates`
- `listMemosForExport`
- `listMemosForLosslessExport`
- `listMemoUidTagRows`
- `getMemoIdByUid`
- `listMemoTagNormalizationRows`
- `listMemoTagBackfillRows`

`AppDatabase` keeps the existing public facade methods and delegates to the query owner.

### Decision 2: Keep search-specific query behavior where it is

`AppDatabase.listMemos` already delegates to `MemoSearchDbPersistence.listRows`, which combines FTS/index behavior with memo list filters. This change does not move that logic.

### Decision 3: Keep write orchestration unchanged

`AppDatabaseWriteDao` still owns tag snapshot transaction orchestration, but the raw memo-tag row read inside that flow delegates to `MemoQueryDbPersistence`. `AppDatabase` also keeps migration/backfill orchestration while delegating the memo tag/id row reads used by those maintenance flows.

## Dependency Direction

Before:

```text
AppDatabase -> memo read/export SQL
AppDatabaseWriteDao -> memo tag scan SQL
```

After:

```text
AppDatabase -> facade delegation -> MemoQueryDbPersistence
AppDatabaseWriteDao -> write orchestration -> MemoQueryDbPersistence for memo tag row reads
MemoQueryDbPersistence -> sqflite only
```

This does not add new `state -> features`, `application -> features`, or `core -> higher layer` imports.

## Risks

- Export ordering and filtering must remain unchanged.
- Lossless export must preserve the `relations_json` join.
- State and sync code may depend on exact row keys, so return shapes must stay compatible.
