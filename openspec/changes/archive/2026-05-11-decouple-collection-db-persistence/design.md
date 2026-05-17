## Context

Collection persistence currently has two different ownership patterns:

- `CollectionsRepository` owns collection CRUD, manual item ordering, logging, and user-facing repository behavior.
- `AppDatabase` owns collection schema and reader-progress reads.
- `AppDatabaseWriteDao` owns reader-progress row writes for desktop write-proxy execution.

The extraction should improve DB file boundaries without forcing a broad repository rewrite.

## Decisions

### Decision 1: Extract table setup and reader-progress primitives

`CollectionDbPersistence` will own:

- `ensureTables`
- `ensureCollectionTables`
- `ensureReaderProgressTable`
- `ensureReaderProgressPageColumns`
- `getReaderProgressRow`
- `upsertReaderProgressRow`
- `deleteReaderProgress`

### Decision 2: Preserve existing higher-level owners

`AppDatabase` remains the lifecycle and facade owner. It decides when collection setup runs from `onCreate` and `onUpgrade`.

`CollectionsRepository` remains the natural owner for collection CRUD and user-facing logging. Its direct collection SQL is not migrated in this change because it includes repository behavior, ordering policy, and log context, not only DB-file coupling.

`AppDatabaseWriteDao` continues to execute reader-progress writes reached through the desktop write proxy, but it delegates table-local SQL to `CollectionDbPersistence`.

### Decision 3: Preserve migration ordering

The previous ordering remains:

- version 21 creates `memo_collections`
- version 22 creates/ensures `memo_collection_items`
- version 23 creates `collection_read_progress`
- version 24 ensures reader page columns

## Dependency Direction

Before:

```text
AppDatabase -> collection schema SQL + reader-progress reads
AppDatabaseWriteDao -> reader-progress write SQL
```

After:

```text
AppDatabase -> lifecycle/facade delegation -> CollectionDbPersistence
AppDatabaseWriteDao -> write proxy execution -> CollectionDbPersistence
CollectionDbPersistence -> sqflite only
```

This does not add new `state -> features`, `application -> features`, or `core -> higher layer` imports.

## Risks

- Reader progress is user-visible in collection reading. Preserve row shape and no-notify behavior.
- Existing v23 databases may lack v24 reader page columns. Keep additive column ensures idempotent.
- Collection CRUD stays in `CollectionsRepository`; guardrails should focus only on preventing `AppDatabase` and `AppDatabaseWriteDao` from re-owning DB-file responsibilities.
