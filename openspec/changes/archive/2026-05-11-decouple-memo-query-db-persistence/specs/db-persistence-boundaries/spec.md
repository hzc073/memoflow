## ADDED Requirements

### Requirement: Memo query DB persistence is extracted into a focused owner
The system SHALL keep table-specific memo read/export SQL in a focused data-layer persistence owner while preserving existing `AppDatabase` facade behavior.

#### Scenario: AppDatabase delegates memo lookup queries
- **WHEN** callers request a memo by `uid`
- **THEN** `AppDatabase` SHALL preserve the public facade
- **AND** the table query SHALL be implemented by `MemoQueryDbPersistence`

#### Scenario: AppDatabase delegates memo scan queries
- **WHEN** callers request tag strings, attachment rows, or memo sync-state rows
- **THEN** result row keys and filtering behavior SHALL remain compatible
- **AND** table queries SHALL be implemented by `MemoQueryDbPersistence`

#### Scenario: AppDatabase delegates export queries
- **WHEN** callers request regular or lossless memo export rows
- **THEN** date filtering, archived filtering, ordering, and limits SHALL remain compatible
- **AND** lossless export SHALL continue to include `relations_json`
- **AND** export SQL SHALL be implemented by `MemoQueryDbPersistence`

#### Scenario: Write and maintenance orchestration delegate memo tag row reads
- **WHEN** tag snapshot write flows or memo tag maintenance flows need to scan memo tag rows
- **THEN** `AppDatabaseWriteDao` and `AppDatabase` SHALL keep transaction and maintenance orchestration
- **AND** memo tag/id row reads SHALL be implemented by `MemoQueryDbPersistence`

#### Scenario: Guardrails protect memo query ownership
- **WHEN** architecture guardrails inspect focused DB persistence files
- **THEN** `MemoQueryDbPersistence` SHALL be checked for higher-layer imports
- **AND** guardrails SHALL fail if `AppDatabase` reintroduces extracted memo query SQL
