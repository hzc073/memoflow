## Why

`stats_cache`, `daily_counts_cache`, and `tag_stats_cache` are the remaining small-table group after memo auxiliary extraction. Their schema, rebuild logic, and memo delta updates still live in `AppDatabase`, and state providers still read the cache tables directly.

The active architecture phase is `evolve_modularity`. This change extracts stats-cache table-specific SQLite behavior into a focused data-layer owner while preserving existing memo write transactions, cache rebuild behavior, state provider outputs, and desktop write-proxy operation names.

## What Changes

- Add `StatsCacheDbPersistence` under `memos_flutter_app/lib/data/db`.
- Move stats cache schema setup, cache row ensures, memo snapshot loading, memo delta application, and full cache rebuild logic out of `AppDatabase`.
- Add `AppDatabase` facade reads for stats cache rows so state providers do not embed stats-cache SQL.
- Keep `AppDatabaseWriteDao` as memo write transaction owner; memo write paths continue to call the existing `AppDatabase` compatibility facade for snapshot/delta payloads.
- Add/tighten architecture guardrails so stats cache SQL does not move back into `AppDatabase` or state providers.

## Non-Goals

- No API route/version changes.
- No schema redesign or database version bump.
- No change to stats provider output semantics.
- No change to desktop write-proxy operation names.
- No migration of core `memos` table persistence.

## Impact

- Runtime files:
  - `memos_flutter_app/lib/data/db/stats_cache_db_persistence.dart`
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - `memos_flutter_app/lib/state/memos/stats_providers.dart`
  - `memos_flutter_app/lib/state/memos/memos_tag_stats_provider.part.dart`
- Tests/guardrails:
  - focused stats provider tests
  - DB migration tests
  - architecture guardrails
