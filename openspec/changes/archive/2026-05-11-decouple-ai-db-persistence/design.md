## Context

The AI table group is cohesive but currently split across two DB files:

- `AppDatabase` creates and upgrades the `ai_*` schema.
- `AppDatabaseWriteDao` performs table-local AI writes and mixed transaction orchestration.

This keeps schema SQL and row primitives inside broad DB owners instead of a focused persistence seam.

## Decisions

### Decision 1: Extract AI table-local SQL into `AiDbPersistence`

`AiDbPersistence` owns:

- `ensureTables`
- AI table `CREATE TABLE` and `CREATE INDEX` SQL
- additive column helpers for `ai_analysis_tasks`
- executor-based write primitives for AI memo policy, index jobs, chunks, embeddings, tasks, results, sections, and evidences
- private AI storage conversion helpers that are only needed for DB rows

### Decision 2: Preserve lifecycle ordering

`AppDatabase` still decides when AI schema work runs from `onCreate` and `onUpgrade`.

For old database versions, migration ordering remains:

- version 14 creates the AI table group
- version 15 ensures `include_public`
- version 26 ensures template snapshot columns

### Decision 3: Preserve transaction and notification ownership

`AppDatabaseWriteDao` continues to own `.transaction(` calls and `notifyDataChanged`.

`AiDbPersistence` accepts `DatabaseExecutor`, `Database`, or `Transaction` supplied by the caller and does not start transactions or notify listeners.

### Decision 4: Keep AI repository reads out of scope

`AiAnalysisRepository` already owns AI read models and desktop write-proxy dispatch. This change keeps those read queries stable and focuses on decoupling DB schema and write primitives from `AppDatabase` and `AppDatabaseWriteDao`.

## Dependency Direction

Before:

```text
AppDatabase -> ai_* schema SQL
AppDatabaseWriteDao -> ai_* write SQL + transaction/notify
```

After:

```text
AppDatabase -> lifecycle ordering -> AiDbPersistence
AppDatabaseWriteDao -> transaction/notify -> AiDbPersistence
AiDbPersistence -> sqflite + data-layer AI models
```

This does not add new `state -> features`, `application -> features`, or `core -> higher layer` imports.

## Risks

- AI analysis result saves insert parent, section, and evidence rows inside one transaction. Keep that transaction in the DAO.
- AI chunk invalidation also marks embeddings and analysis results stale. Preserve the exact SQL behavior inside the executor-scoped primitive.
- AI migration compatibility depends on additive columns staying idempotent.
