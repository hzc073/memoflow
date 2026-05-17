## Why

`db-persistence-boundaries` Batch 5 calls for extracting small DB table groups without one-file-per-table churn. After evaluating the remaining small tables, `memo_reminders`, `import_history`, and `memo_clip_cards` are cohesive enough to extract together because they are memo-adjacent support tables with simple schema and row primitives still owned by `AppDatabase` / `AppDatabaseWriteDao`.

`stats_cache`, `daily_counts_cache`, and `tag_stats_cache` are intentionally deferred because they are tightly coupled to memo write delta logic and state-layer stats readers. They should be handled in a dedicated stats-cache change rather than mixed into this low-risk auxiliary extraction.

## What Changes

- Add `MemoAuxiliaryDbPersistence` under `memos_flutter_app/lib/data/db`.
- Move schema setup for `memo_reminders`, `import_history`, and `memo_clip_cards` out of `AppDatabase`.
- Move read helpers for memo reminders, import history, and memo clip cards out of `AppDatabase`.
- Move row primitives for memo reminders, import history, and memo clip cards out of `AppDatabaseWriteDao`.
- Preserve desktop write-proxy operation names/payloads and `notifyDataChanged` behavior.
- Keep memo clip card FTS refresh orchestration in `AppDatabaseWriteDao`; only the table-local clip-card row primitive moves.
- Add/tighten architecture guardrails for the new persistence owner.

## Non-Goals

- No API route/version changes.
- No schema redesign or database version bump.
- No stats cache extraction in this change.
- No change to memo search document behavior or clip-card FTS refresh policy.
- No caller migration away from existing `AppDatabase` facade methods.

## Impact

- Runtime files:
  - `memos_flutter_app/lib/data/db/memo_auxiliary_db_persistence.dart`
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - `memos_flutter_app/lib/data/db/app_database_write_dao.dart`
- Tests/guardrails:
  - DB migration tests
  - clip-card tests
  - reminder/import focused tests as applicable
  - architecture guardrails
