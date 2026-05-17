## ADDED Requirements

### Requirement: Tag DB persistence is extracted into a focused owner
The system SHALL keep table-specific SQLite details for `tags`, `tag_aliases`, and `memo_tags` in a focused data-layer persistence owner while preserving existing facade and repository behavior.

#### Scenario: Tag table setup is delegated from lifecycle
- **WHEN** `AppDatabase` creates or upgrades the local database
- **THEN** `AppDatabase` SHALL continue to control lifecycle ordering
- **AND** tag table and index SQL SHALL be implemented by `TagDbPersistence`

#### Scenario: Tag reads use the persistence owner
- **WHEN** tag repository code lists tags, looks up a tag by path, or reads a tag snapshot
- **THEN** it SHALL call `TagDbPersistence` read primitives
- **AND** it SHALL NOT embed `tags` or `tag_aliases` SQL in state-layer repository code

#### Scenario: Tag writes keep existing transaction ownership
- **WHEN** tag create, update, delete, snapshot apply, or memo tag mapping behavior mutates tag rows
- **THEN** the transaction boundary SHALL remain in `AppDatabaseWriteDao` or an approved write owner
- **AND** `TagDbPersistence` SHALL accept a `DatabaseExecutor`, `Database`, or `Transaction` from its caller
- **AND** `TagDbPersistence` SHALL NOT call `.transaction(`

#### Scenario: Tag compatibility is preserved
- **WHEN** tag persistence is extracted
- **THEN** existing tag path ordering, alias resolution, snapshot restore behavior, memo tag text rewrites, search refresh side effects, and stats-cache side effects SHALL remain compatible
- **AND** existing desktop tag repository write operation names and payload keys SHALL remain stable

#### Scenario: Guardrails protect tag persistence ownership
- **WHEN** architecture guardrails inspect focused DB persistence files
- **THEN** `TagDbPersistence` SHALL be checked for higher-layer imports
- **AND** guardrails SHALL fail if `AppDatabase` reintroduces direct `tags`, `tag_aliases`, or `memo_tags` schema SQL or extracted tag table-local helper ownership
