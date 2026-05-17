## ADDED Requirements

### Requirement: AI DB persistence is extracted into a focused owner
The system SHALL keep table-specific SQLite details for the AI table group in a focused data-layer persistence owner while preserving existing AI repository, desktop write-proxy, transaction, and notification behavior.

#### Scenario: AI table setup is delegated from AppDatabase
- **WHEN** `AppDatabase` creates or upgrades the local database
- **THEN** `AppDatabase` SHALL continue to control lifecycle ordering
- **AND** AI table SQL for `ai_memo_policy`, `ai_chunks`, `ai_embeddings`, `ai_index_jobs`, `ai_analysis_tasks`, `ai_analysis_results`, `ai_analysis_sections`, and `ai_analysis_evidences` SHALL be implemented by `AiDbPersistence`

#### Scenario: AI additive columns use the persistence owner
- **WHEN** existing databases are upgraded across AI schema versions
- **THEN** additive column checks for `ai_analysis_tasks` SHALL be implemented by `AiDbPersistence`
- **AND** migration ordering SHALL remain compatible with existing version gates

#### Scenario: AI writes keep existing transaction ownership
- **WHEN** AI rows are mutated for memo policy, index jobs, chunks, embeddings, tasks, or analysis results
- **THEN** the transaction boundary SHALL remain in `AppDatabaseWriteDao` or another approved write owner
- **AND** `AiDbPersistence` SHALL accept a caller-provided executor for write primitives
- **AND** `AiDbPersistence` SHALL NOT call `.transaction(`

#### Scenario: AI compatibility is preserved
- **WHEN** AI persistence is extracted
- **THEN** desktop write-proxy operation names, payload keys, result shapes, task state codes, result row shapes, and notification behavior SHALL remain compatible

#### Scenario: Guardrails protect AI persistence ownership
- **WHEN** architecture guardrails inspect focused DB persistence files
- **THEN** `AiDbPersistence` SHALL be checked for higher-layer imports
- **AND** guardrails SHALL fail if `AppDatabase` reintroduces direct AI table schema SQL or `AppDatabaseWriteDao` reintroduces AI table-local write primitives
