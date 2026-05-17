## ADDED Requirements

### Requirement: Memo auxiliary DB persistence is extracted into a focused owner
The system SHALL keep table-specific SQLite details for selected memo-adjacent small tables in a focused data-layer persistence owner while preserving existing facade, desktop write-proxy, transaction, notification, and search-refresh behavior.

#### Scenario: Selected small-table setup is delegated from AppDatabase
- **WHEN** `AppDatabase` creates or upgrades the local database
- **THEN** `AppDatabase` SHALL continue to control lifecycle ordering
- **AND** schema/index SQL for `memo_reminders`, `import_history`, and `memo_clip_cards` SHALL be implemented by `MemoAuxiliaryDbPersistence`

#### Scenario: Selected small-table reads use the persistence owner
- **WHEN** callers read memo reminders, import history, or memo clip cards through existing `AppDatabase` facade methods
- **THEN** the table-local read queries SHALL be delegated to `MemoAuxiliaryDbPersistence`
- **AND** existing ordering and return row shapes SHALL remain compatible

#### Scenario: Selected small-table writes keep existing orchestration
- **WHEN** memo reminders, import history, or memo clip cards are mutated
- **THEN** row primitives SHALL be implemented by `MemoAuxiliaryDbPersistence`
- **AND** transaction boundaries and `notifyDataChanged` SHALL remain owned by `AppDatabaseWriteDao` or another approved write owner
- **AND** memo clip-card mutations SHALL continue to refresh memo search rows in the same transaction

#### Scenario: Stats cache is deferred explicitly
- **WHEN** this memo auxiliary extraction is implemented
- **THEN** `stats_cache`, `daily_counts_cache`, and `tag_stats_cache` MAY remain in their current owner
- **AND** a future stats-cache extraction SHALL scope cache rebuild and memo delta behavior separately

#### Scenario: Guardrails protect memo auxiliary persistence ownership
- **WHEN** architecture guardrails inspect focused DB persistence files
- **THEN** `MemoAuxiliaryDbPersistence` SHALL be checked for higher-layer imports
- **AND** guardrails SHALL fail if `AppDatabase` or `AppDatabaseWriteDao` reintroduces selected small-table SQLite details that belong in the persistence owner
