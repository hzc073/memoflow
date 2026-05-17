## Why

`AppDatabase` is still a large SQLite persistence hotspot even after `ComposeDraftDbPersistence`, `MemoSearchDbPersistence`, and `OutboxDbPersistence` were extracted. Repeated ad-hoc exploration before each DB split wastes time and increases the risk that future batches disagree on ownership boundaries.

Current architecture phase is `evolve_modularity`. This roadmap mainly touches checklist items 7, 8, 9, and 10 by defining table ownership, guardrail expectations, OpenSpec documentation, and “equal or better structured” behavior for future DB persistence changes; it also supports the long-term reduction of critical coupling items 1-4 by keeping lower data-layer seams free of upward dependencies.

## What Changes

- Add a new `db-persistence-boundaries` capability that defines the phased roadmap for decoupling SQLite table-specific persistence from `AppDatabase` and `AppDatabaseWriteDao`.
- Codify stable boundaries for `AppDatabase`, `AppDatabaseWriteDao`, and focused `*DbPersistence` owners so future batches do not need to rediscover the same decisions.
- Define recommended batch order for remaining DB persistence extraction:
  - `decouple-tag-db-persistence`
  - `decouple-memo-lifecycle-db-persistence`
  - `decouple-ai-db-persistence`
  - `decouple-collections-db-persistence`
  - `decouple-small-db-tables`
  - optional final `decouple-memo-core-db-persistence`
- Treat already completed compose draft, memo search, and outbox extractions as precedents rather than targets for this roadmap.
- Define non-goals for the roadmap: no application code implementation, no DB schema redesign, no API route/version changes, and no broad caller migration unless a later concrete change explicitly scopes it.

## Capabilities

### New Capabilities

- `db-persistence-boundaries`: Defines phased SQLite persistence extraction boundaries, batch ordering, and guardrail expectations for `AppDatabase`, `AppDatabaseWriteDao`, and focused `*DbPersistence` owners.

### Modified Capabilities

- None. This change applies the existing `modularity-governance` phase rules to DB persistence planning, but it does not change checklist semantics, critical items, preserve-phase gates, or approved boundary exceptions.

## Impact

- Affected planning surface:
  - `openspec/specs/db-persistence-boundaries/spec.md`
  - future OpenSpec changes for tags, memo lifecycle tables, AI tables, collections, small DB tables, and possibly core memo persistence
- Affected code areas for future implementation batches:
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - `memos_flutter_app/lib/data/db/app_database_write_dao.dart`
  - focused files such as `tag_db_persistence.dart`, `memo_lifecycle_db_persistence.dart`, `ai_db_persistence.dart`, `collection_db_persistence.dart`, and similar table owners
  - architecture guardrails under `memos_flutter_app/test/architecture/...`
- No runtime behavior, public API, desktop write-proxy protocol, sync protocol, or SQLite schema changes are made by this roadmap itself.
