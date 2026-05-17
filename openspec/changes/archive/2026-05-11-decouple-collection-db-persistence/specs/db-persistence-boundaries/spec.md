## ADDED Requirements

### Requirement: Collection DB persistence is extracted into a focused owner
The system SHALL keep table setup and reader-progress SQLite details for the collection table group in a focused data-layer persistence owner while preserving existing collection repository, desktop write-proxy, and reader behavior.

#### Scenario: Collection table setup is delegated from AppDatabase
- **WHEN** `AppDatabase` creates or upgrades the local database
- **THEN** `AppDatabase` SHALL continue to control lifecycle ordering
- **AND** schema/index SQL for `memo_collections`, `memo_collection_items`, and `collection_read_progress` SHALL be implemented by `CollectionDbPersistence`

#### Scenario: Reader-progress additive columns use the persistence owner
- **WHEN** existing databases are upgraded across collection reader versions
- **THEN** additive column checks for `collection_read_progress` SHALL be implemented by `CollectionDbPersistence`
- **AND** migration ordering SHALL remain compatible with existing version gates

#### Scenario: Reader-progress writes keep existing execution behavior
- **WHEN** `collection_read_progress` rows are inserted, replaced, read, or deleted
- **THEN** table-local SQLite primitives SHALL be implemented by `CollectionDbPersistence`
- **AND** `AppDatabase` and `AppDatabaseWriteDao` SHALL preserve existing desktop write-proxy and no-notify behavior

#### Scenario: Collection repository remains the CRUD owner
- **WHEN** collection rows or manual item rows are listed, ordered, logged, created, updated, or deleted
- **THEN** `CollectionsRepository` MAY continue to own that repository behavior
- **AND** this extraction SHALL NOT require a collection UI or repository protocol migration

#### Scenario: Guardrails protect collection persistence ownership
- **WHEN** architecture guardrails inspect focused DB persistence files
- **THEN** `CollectionDbPersistence` SHALL be checked for higher-layer imports
- **AND** guardrails SHALL fail if `AppDatabase` reintroduces direct collection schema SQL or `AppDatabaseWriteDao` reintroduces reader-progress table-local write primitives
