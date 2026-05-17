## ADDED Requirements

### Requirement: Memo write DB persistence is extracted into a focused owner
The system SHALL keep table-local `memos` write primitives in a focused data-layer persistence owner while preserving existing memo write orchestration behavior.

#### Scenario: AppDatabaseWriteDao delegates memo row sync updates
- **WHEN** memo write flows update sync state or attachments JSON
- **THEN** `AppDatabaseWriteDao` SHALL preserve public write behavior and notifications
- **AND** direct `memos` row update SQL SHALL be implemented by `MemoWriteDbPersistence`

#### Scenario: AppDatabaseWriteDao delegates memo row upsert and delete primitives
- **WHEN** memo write flows insert, update, rename, or delete memo rows
- **THEN** transaction boundaries and write orchestration SHALL remain in `AppDatabaseWriteDao`
- **AND** table-local `memos` insert/update/delete SQL SHALL be implemented by `MemoWriteDbPersistence`

#### Scenario: Write-side supporting row reads are delegated
- **WHEN** write orchestration needs memo row data for attachment placeholder cleanup or search refresh
- **THEN** result semantics SHALL remain compatible
- **AND** direct `memos` row query SQL SHALL be implemented by `MemoWriteDbPersistence`

#### Scenario: Cross-table orchestration remains outside memo write persistence
- **WHEN** memo writes coordinate tags, FTS/index refresh, stats cache deltas, lifecycle cleanup, auxiliary rows, or outbox rows
- **THEN** those orchestration calls SHALL remain outside `MemoWriteDbPersistence`
- **AND** `MemoWriteDbPersistence` SHALL NOT import higher layers or unrelated DB persistence owners

#### Scenario: Guardrails protect memo write ownership
- **WHEN** architecture guardrails inspect focused DB persistence files
- **THEN** `MemoWriteDbPersistence` SHALL be checked for higher-layer imports
- **AND** guardrails SHALL fail if `AppDatabaseWriteDao` reintroduces extracted direct `memos` table primitives
