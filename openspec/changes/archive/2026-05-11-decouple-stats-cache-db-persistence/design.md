## Context

Stats cache behavior has three layers today:

- `AppDatabase` owns `stats_cache`, `daily_counts_cache`, and `tag_stats_cache` schema.
- `AppDatabase` owns full rebuild and incremental memo delta logic.
- state providers read the cache tables directly.

This keeps table-specific SQLite scattered across DB facade and state-layer readers.

## Decisions

### Decision 1: Extract stats-cache persistence as one focused owner

`StatsCacheDbPersistence` owns:

- `ensureTables`
- cache row ensure
- full rebuild SQL and memo scan
- memo snapshot loading
- memo snapshot payload conversion
- incremental memo cache delta updates
- basic read queries for local stats and tag stats providers

### Decision 2: Preserve transaction ownership

`StatsCacheDbPersistence` does not call `.transaction(` directly. For full rebuild, `AppDatabase` passes the existing approved transaction runner (`AppDatabaseWriteDao.runTransaction`) into the persistence helper.

Memo write transactions remain in `AppDatabaseWriteDao`; the DAO continues to call `AppDatabase.loadMemoSnapshotPayload`, `AppDatabase.createMemoSnapshotPayload`, and `AppDatabase.applyMemoCacheDeltaPayload`, which now delegate to `StatsCacheDbPersistence`.

### Decision 3: Keep state providers SQL-free for stats cache

`localStatsProvider` and `tagStatsProvider` keep their mapping and UI-facing model logic, but table reads go through `AppDatabase` facade methods backed by `StatsCacheDbPersistence`.

## Dependency Direction

Before:

```text
AppDatabase -> stats cache schema + rebuild + delta SQL
state/memos -> stats cache read SQL
```

After:

```text
AppDatabase -> lifecycle/facade delegation -> StatsCacheDbPersistence
AppDatabaseWriteDao -> transaction/memo orchestration -> AppDatabase facade -> StatsCacheDbPersistence
state/memos -> AppDatabase facade reads
StatsCacheDbPersistence -> sqflite + core tag splitting
```

This does not add new `state -> features`, `application -> features`, or `core -> higher layer` imports.

## Risks

- Incremental cache deltas are exercised by memo writes and deletes. Preserve the existing payload facade used by `AppDatabaseWriteDao`.
- Full rebuild scans the core `memos` table. Keep batching and transaction behavior compatible.
- Tag stats provider previously had fallback behavior when joined reads failed. Preserve fallback in the persistence helper.
