## ADDED Requirements

### Requirement: Stats cache DB persistence is extracted into a focused owner
The system SHALL keep table-specific SQLite details for stats cache tables in a focused data-layer persistence owner while preserving existing memo write, cache rebuild, state provider, and desktop write-proxy behavior.

#### Scenario: Stats cache setup is delegated from AppDatabase
- **WHEN** `AppDatabase` creates, upgrades, or opens the local database
- **THEN** `AppDatabase` SHALL continue to control lifecycle ordering
- **AND** schema SQL for `stats_cache`, `daily_counts_cache`, and `tag_stats_cache` SHALL be implemented by `StatsCacheDbPersistence`

#### Scenario: Stats cache rebuild uses the persistence owner
- **WHEN** stats cache rows are missing or a rebuild is requested
- **THEN** full rebuild logic SHALL be implemented by `StatsCacheDbPersistence`
- **AND** transaction execution SHALL remain supplied by an approved owner rather than direct `.transaction(` calls inside `StatsCacheDbPersistence`

#### Scenario: Memo write deltas use the persistence owner
- **WHEN** memo write paths need to update cached stats incrementally
- **THEN** memo snapshot loading, snapshot payload conversion, daily count updates, tag count updates, and summary row updates SHALL be implemented by `StatsCacheDbPersistence`
- **AND** existing `AppDatabase` snapshot/delta facade methods SHALL remain compatible for `AppDatabaseWriteDao`

#### Scenario: State providers do not own stats cache SQL
- **WHEN** state providers load local stats or tag stats
- **THEN** they SHALL call `AppDatabase` facade methods backed by `StatsCacheDbPersistence`
- **AND** they SHALL NOT embed direct SQL for `stats_cache`, `daily_counts_cache`, or `tag_stats_cache`

#### Scenario: Guardrails protect stats cache ownership
- **WHEN** architecture guardrails inspect focused DB persistence files and state providers
- **THEN** `StatsCacheDbPersistence` SHALL be checked for higher-layer imports
- **AND** guardrails SHALL fail if `AppDatabase` or state providers reintroduce extracted stats cache SQL
