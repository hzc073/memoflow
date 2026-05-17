## ADDED Requirements

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
