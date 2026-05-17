## Why

`db-persistence-boundaries` lists AI tables as Batch 3 after tag and memo lifecycle extraction. `AppDatabase` still owns `ai_*` schema SQL, while `AppDatabaseWriteDao` owns table-local AI write primitives for memo policy, index jobs, chunks, embeddings, and analysis result rows.

The active architecture phase is `evolve_modularity`. This change improves checklist items 7, 8, 9, and 10 by moving table-local AI SQLite details into a focused data-layer owner while preserving existing transaction, notification, and desktop write-proxy behavior.

## What Changes

- Add `AiDbPersistence` under `memos_flutter_app/lib/data/db`.
- Move `ai_memo_policy`, `ai_chunks`, `ai_embeddings`, `ai_index_jobs`, `ai_analysis_tasks`, `ai_analysis_results`, `ai_analysis_sections`, and `ai_analysis_evidences` schema/index/additive-column helpers out of `AppDatabase`.
- Move executor-scoped AI row primitives out of `AppDatabaseWriteDao`.
- Keep `AppDatabase` as lifecycle and facade owner.
- Keep `AppDatabaseWriteDao` as transaction and `notifyDataChanged` owner.
- Keep AI repository read queries and desktop write-proxy operation names/payload keys stable.
- Add/tighten guardrails so focused DB persistence files stay lower-layer and `AppDatabase`/`AppDatabaseWriteDao` do not re-own extracted AI SQL.

## Non-Goals

- No API route/version changes.
- No AI feature behavior changes.
- No AI repository read-query migration unless needed for the extraction.
- No schema redesign or database version bump.
- No desktop write-proxy protocol migration.

## Impact

- Runtime files:
  - `memos_flutter_app/lib/data/db/ai_db_persistence.dart`
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - `memos_flutter_app/lib/data/db/app_database_write_dao.dart`
- Tests/guardrails:
  - focused AI repository tests
  - DB migration tests
  - architecture guardrails
