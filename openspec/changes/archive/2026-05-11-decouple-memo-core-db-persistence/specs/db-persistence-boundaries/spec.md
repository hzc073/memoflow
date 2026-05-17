## ADDED Requirements

### Requirement: Core memo DB schema is extracted into a focused owner
The system SHALL keep table-specific SQLite schema and migration details for the core memo tables in a focused data-layer persistence owner while preserving existing database lifecycle ordering and memo write behavior.

#### Scenario: Core memo setup is delegated from AppDatabase
- **WHEN** `AppDatabase` creates the local database
- **THEN** `AppDatabase` SHALL continue to control lifecycle ordering
- **AND** schema SQL for `memos` and legacy `attachments` SHALL be implemented by `MemoCoreDbPersistence`

#### Scenario: Core memo column migrations are delegated from AppDatabase
- **WHEN** `AppDatabase` upgrades old database versions that need core memo columns
- **THEN** relation-count, location, and display-time migration behavior SHALL be implemented by `MemoCoreDbPersistence`
- **AND** the `display_time` backfill SHALL still set missing values from `create_time`

#### Scenario: Memo count uses the persistence owner
- **WHEN** callers request the local memo count through `AppDatabase.countMemos`
- **THEN** `AppDatabase` SHALL preserve the public facade
- **AND** the SQL query SHALL be implemented by `MemoCoreDbPersistence`

#### Scenario: Legacy attachment table primitives are delegated
- **WHEN** memo UID rename flows need to update legacy attachment ownership
- **THEN** `AppDatabaseWriteDao` SHALL keep transaction orchestration
- **AND** table-local SQL for updating `attachments.memo_uid` SHALL be implemented by `MemoCoreDbPersistence`

#### Scenario: Guardrails protect core memo persistence ownership
- **WHEN** architecture guardrails inspect focused DB persistence files
- **THEN** `MemoCoreDbPersistence` SHALL be checked for higher-layer imports
- **AND** guardrails SHALL fail if `AppDatabase` reintroduces extracted core memo schema or migration SQL
- **AND** guardrails SHALL fail if `AppDatabaseWriteDao` reintroduces extracted legacy attachment table SQL
