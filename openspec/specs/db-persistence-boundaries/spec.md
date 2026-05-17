# db-persistence-boundaries Specification

## Purpose

Define the phased DB persistence extraction roadmap and boundary rules for moving table-specific SQLite responsibilities out of `AppDatabase` and `AppDatabaseWriteDao` into focused data-layer `*DbPersistence` owners.
## Requirements
### Requirement: DB persistence extraction roadmap is explicit
The system SHALL maintain an explicit phased roadmap for extracting table-specific SQLite persistence responsibilities out of the monolithic `AppDatabase` implementation.

#### Scenario: Future DB extraction starts from the roadmap
- **WHEN** a future OpenSpec change proposes another DB persistence extraction
- **THEN** the change SHALL identify the target batch from the DB persistence roadmap or explain why it intentionally deviates
- **AND** the change SHALL define the affected table group before implementation starts

#### Scenario: Completed precedents remain recognized
- **WHEN** future DB persistence extraction work is planned
- **THEN** `ComposeDraftDbPersistence`, `MemoSearchDbPersistence`, and `OutboxDbPersistence` SHALL be treated as completed precedents
- **AND** the roadmap SHALL NOT ask future changes to rediscover their already-decided ownership boundaries

### Requirement: AppDatabase remains lifecycle and facade owner
`AppDatabase` SHALL remain the owner of database lifecycle, migration ordering, public compatibility facade methods, and desktop write-proxy dispatch while table-specific SQLite details are extracted into focused data-layer persistence owners.

#### Scenario: Public facade compatibility is preserved during extraction
- **WHEN** a concrete DB persistence extraction is implemented
- **THEN** existing public `AppDatabase` methods for the extracted table group SHALL remain compatible unless that change explicitly declares caller migration scope
- **AND** existing return shapes, ordering, state codes, payload keys, and error behavior SHALL remain stable where callers continue through the facade

#### Scenario: Lifecycle ordering remains centralized
- **WHEN** table creation, additive column ensure, legacy normalization, or index creation is moved to a focused persistence owner
- **THEN** `AppDatabase` SHALL continue to control when that work runs from `onCreate`, `onUpgrade`, and `onOpen`
- **AND** the extraction SHALL preserve the previous migration ordering for existing databases

#### Scenario: Desktop write proxy protocol remains stable
- **WHEN** extracted table writes are reachable through desktop write-proxy dispatch
- **THEN** operation names and payload keys SHALL remain stable unless the concrete change explicitly scopes a protocol migration

### Requirement: AppDatabaseWriteDao remains transaction and notification owner
`AppDatabaseWriteDao` SHALL remain the default owner of direct transaction boundaries, mixed write orchestration, and data-change notifications for DB persistence extractions.

#### Scenario: Persistence helpers do not start transactions
- **WHEN** a focused `*DbPersistence` helper is added or changed
- **THEN** it SHALL accept a `DatabaseExecutor`, `Database`, or `Transaction` from its caller for write primitives
- **AND** it SHALL NOT call `.transaction(` directly unless the concrete change explicitly approves and guards the exception

#### Scenario: Mixed writes remain atomic
- **WHEN** a write operation must update the extracted table group and other tables in the same logical mutation
- **THEN** the transaction boundary SHALL remain in `AppDatabaseWriteDao` or another approved write owner
- **AND** the focused persistence helper SHALL only perform executor-scoped primitives inside that existing boundary

#### Scenario: Notifications remain outside persistence helpers
- **WHEN** extracted persistence primitives mutate local rows
- **THEN** `notifyDataChanged` policy SHALL remain owned by `AppDatabase`, `AppDatabaseWriteDao`, or another approved write owner
- **AND** focused persistence helpers SHALL NOT own UI, provider, or notification policy

### Requirement: Focused DB persistence owners contain table-specific SQLite details
Each focused DB persistence owner SHALL contain table-specific SQLite schema, migration helpers, queries, and row-level primitives for its table group while avoiding higher-layer dependencies.

#### Scenario: Persistence owner contains table-local SQL
- **WHEN** a table group is extracted from `AppDatabase`
- **THEN** its focused persistence owner SHALL contain the table-local `CREATE TABLE`, `CREATE INDEX`, additive column ensure, table-local legacy normalization, read queries, and executor-based write primitives needed by that group

#### Scenario: Persistence owner avoids upward imports
- **WHEN** architecture guardrails inspect focused DB persistence files under `lib/data/db`
- **THEN** those files SHALL NOT import `features/`, `state/`, or `application/`
- **AND** future extraction changes SHALL NOT introduce new `state -> features`, `application -> features`, or `core -> state|application|features` imports

#### Scenario: Reusable non-SQL logic does not hide in AppDatabase
- **WHEN** extracted persistence needs reusable domain logic that is not table-local SQL
- **THEN** that logic SHALL live in a reusable lower data/core seam or an approved owner
- **AND** it SHALL NOT be kept as unrelated static utility behavior on `AppDatabase`

### Requirement: DB persistence batches follow risk-based order
Future DB persistence extraction SHALL follow risk-based batching unless a concrete change justifies a different order.

#### Scenario: Tags are the next natural batch
- **WHEN** the next DB persistence extraction is selected after compose draft, memo search, and outbox
- **THEN** tag persistence SHALL be considered the preferred next batch because tag schema, mapping, normalization, and mutation primitives are cohesive and already have repository-level caller ownership

#### Scenario: Memo lifecycle tables are separated before core memos
- **WHEN** memo lifecycle persistence is extracted
- **THEN** related tables such as `memo_versions`, `recycle_bin_items`, `memo_delete_tombstones`, `memo_relations_cache`, and `memo_inline_image_sources` SHALL be considered before extracting the core `memos` table
- **AND** mixed memo/outbox/search/local-library transaction behavior SHALL remain owned by approved write owners

#### Scenario: AI tables are treated as a cohesive group
- **WHEN** AI DB persistence is extracted
- **THEN** `ai_*` schema, index, job, chunk, embedding, analysis task, result, section, and evidence table persistence SHALL be evaluated as one cohesive table group unless the concrete change narrows scope explicitly

#### Scenario: Collections and small tables are lower-risk cleanup batches
- **WHEN** collection or small-table persistence is extracted
- **THEN** `memo_collections`, `memo_collection_items`, `collection_read_progress`, `memo_reminders`, `import_history`, and `memo_clip_cards` SHALL be grouped by natural ownership rather than split mechanically when grouping is clearer

#### Scenario: Core memos table remains last or explicitly deferred
- **WHEN** core memo row persistence is considered for extraction
- **THEN** it SHALL be treated as the highest-risk batch
- **AND** it SHALL happen only after surrounding table groups are clearer or be explicitly deferred as an acceptable end state

### Requirement: Each concrete DB extraction includes guardrail verification
Each concrete DB persistence extraction SHALL include automated or focused verification that protects the new boundary and preserves behavior.

#### Scenario: Guardrails protect dependency direction
- **WHEN** a concrete extraction adds or changes focused DB persistence files
- **THEN** architecture guardrails SHALL verify that those files do not import higher layers
- **AND** any direct transaction allowlist expansion SHALL require explicit design justification

#### Scenario: Guardrails protect AppDatabase from re-owning extracted details
- **WHEN** a concrete extraction completes
- **THEN** tests or guardrails SHALL verify that `AppDatabase` no longer directly owns the extracted table group's schema SQL and table-local helper logic
- **AND** `AppDatabase` MAY still expose public facade methods, lifecycle calls, desktop write-proxy dispatch, and compatibility constants

#### Scenario: Behavior compatibility is verified
- **WHEN** a concrete extraction changes SQL ownership for an existing table group
- **THEN** focused tests SHALL verify row compatibility, migration compatibility, ordering, filters, write side effects, and notification behavior relevant to that table group

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

