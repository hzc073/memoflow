## ADDED Requirements

### Requirement: Memo lifecycle DB persistence is extracted into a focused owner
The system SHALL keep table-specific SQLite details for memo lifecycle support tables in a focused data-layer persistence owner while preserving existing facade and write-owner behavior.

#### Scenario: Lifecycle table setup is delegated from AppDatabase
- **WHEN** `AppDatabase` creates or upgrades the local database
- **THEN** `AppDatabase` SHALL continue to control lifecycle ordering
- **AND** lifecycle table SQL for `memo_versions`, `recycle_bin_items`, `memo_delete_tombstones`, `memo_relations_cache`, and `memo_inline_image_sources` SHALL be implemented by `MemoLifecycleDbPersistence`

#### Scenario: Lifecycle reads use the persistence owner
- **WHEN** callers list or fetch lifecycle rows
- **THEN** they SHALL call `MemoLifecycleDbPersistence` read primitives
- **AND** they SHALL NOT embed lifecycle table SQL in `AppDatabase` or state-layer code

#### Scenario: Lifecycle writes keep existing transaction ownership
- **WHEN** lifecycle tables are mutated as part of memo delete, recycle bin, or inline image flows
- **THEN** the transaction boundary SHALL remain in `AppDatabaseWriteDao` or another approved write owner
- **AND** `MemoLifecycleDbPersistence` SHALL accept a `DatabaseExecutor`, `Database`, or `Transaction` from its caller for write primitives
- **AND** `MemoLifecycleDbPersistence` SHALL NOT call `.transaction(`

#### Scenario: Lifecycle compatibility is preserved
- **WHEN** lifecycle persistence is extracted
- **THEN** existing ordering, state codes, payload shapes, notification behavior, and mixed memo/outbox interactions SHALL remain compatible

#### Scenario: Guardrails protect lifecycle persistence ownership
- **WHEN** architecture guardrails inspect focused DB persistence files
- **THEN** `MemoLifecycleDbPersistence` SHALL be checked for higher-layer imports
- **AND** guardrails SHALL fail if `AppDatabase` reintroduces direct lifecycle table schema SQL or table-local helper ownership
