## ADDED Requirements

### Requirement: Managed local library paths SHALL be derived from current app data container

`LocalLibraryStorageKind.managedPrivate` 的路径 SHALL be derived from the workspace key and the current app data container. Persisted absolute `rootPath` values from previous iOS containers MUST NOT be treated as authoritative.

#### Scenario: Managed library has stale iOS container path

- **GIVEN** a managed private local library has `rootPath` pointing to an old iOS App container
- **WHEN** local libraries are loaded or migrated
- **THEN** the system SHALL resolve the current managed workspace path from the library key
- **AND** the loaded library SHALL use the current path before local sync attempts `ensureStructure`
- **AND** the system MUST NOT attempt to create directories under the old App container path

#### Scenario: Managed library path is persisted or cached after rebase

- **WHEN** a managed private library is rebased to the current app container path
- **THEN** the corrected path SHALL be persisted or cached through the local library repository/provider seam
- **AND** subsequent `currentLocalLibraryProvider` reads SHALL expose the corrected path

### Requirement: Local library metadata SHALL not be secure-storage-only long term

Local library list and managed private workspace metadata are non-secret app data. The system SHALL store them in an app-data storage owner such as App Support, while secure storage remains responsible for secrets such as account tokens.

#### Scenario: Existing secure-storage local library state is migrated

- **GIVEN** legacy `local_library_state_v1` exists in secure storage
- **AND** the new app-data local library metadata store is empty
- **WHEN** the app loads local libraries
- **THEN** the repository SHALL read the legacy state as a migration source
- **AND** managed private libraries SHALL be rebased to current container paths during migration
- **AND** the migrated state SHALL be written to the app-data metadata store

#### Scenario: App-data metadata is authoritative after migration

- **GIVEN** app-data local library metadata exists
- **WHEN** the app loads local libraries
- **THEN** the repository SHALL use app-data metadata as the authoritative source
- **AND** legacy secure-storage local library metadata SHALL NOT override the app-data state

#### Scenario: Secrets remain in secure storage

- **WHEN** local library metadata storage is changed
- **THEN** account tokens, credentials, and other secret account data SHALL remain in secure storage
- **AND** the change MUST NOT move secrets into plain App Support JSON

### Requirement: Stale local workspace metadata SHALL be reconciled safely

When secure storage survives but the current App Support/database data for a local workspace is absent, the system SHALL treat the local workspace metadata as stale or recoverable rather than using old absolute paths.

#### Scenario: Keychain references local workspace after app data reset

- **GIVEN** secure storage contains `session.currentKey` or legacy local library metadata for a local workspace
- **AND** the current App Support workspace directory, local library files, and workspace database are all absent after a stable probe
- **WHEN** startup or local library load reconciles workspace state
- **THEN** the system SHALL NOT use stale `rootPath` from secure storage
- **AND** the stale local workspace SHALL NOT be silently treated as a fully available existing workspace
- **AND** the route/session state SHALL be cleared, repaired, or moved to an explicit recoverable state through an approved provider/app shell seam

#### Scenario: Existing empty workspace remains valid

- **GIVEN** a managed local workspace exists in the current App Support container but has no memos yet
- **WHEN** local libraries are loaded
- **THEN** the system SHALL preserve that workspace
- **AND** it SHALL NOT classify the workspace as stale solely because the memo count is zero

### Requirement: Local sync SHALL be safe after path rebase

Path rebase SHALL prevent filesystem permission errors without causing data loss or broad cleanup side effects.

#### Scenario: Sync creates structure in current path

- **GIVEN** the active local library was rebased from a stale path to the current managed path
- **WHEN** `LocalSyncController.syncNow()` calls `LocalLibraryFileSystem.ensureStructure()`
- **THEN** `memos`, `memos/_meta`, and `attachments` directories SHALL be created under the current managed path
- **AND** no `PathAccessException` SHALL be raised due to the old iOS container path

#### Scenario: Empty rebased directory does not delete DB memos

- **GIVEN** the rebased local library directory is empty
- **AND** the local database still contains memos
- **WHEN** incremental local scan runs without a prior manifest proving disk deletions
- **THEN** the scan SHALL NOT delete all database memos merely because the rebased directory is empty
- **AND** any DB-to-disk rebuild behavior SHALL be explicit, tested, and owned by sync or repair logic

### Requirement: Managed local library storage changes SHALL preserve architecture boundaries

Managed local library storage repair SHALL remain owned by data/application/state seams and MUST NOT move reusable workspace or filesystem logic into feature widgets.

#### Scenario: Storage repair avoids reverse dependencies

- **WHEN** managed local library path rebase, metadata migration, or stale reconciliation is implemented
- **THEN** it MUST NOT introduce new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies
- **AND** settings/home widgets MUST NOT directly inspect App Support paths, database files, or legacy secure-storage payloads

#### Scenario: Public repository remains commercial-free

- **WHEN** managed local library storage behavior is changed
- **THEN** implementation MUST NOT add subscription, billing, entitlement, receipt, paywall, StoreKit, product ID, price, private overlay, or `AccessDecision.source` business branching logic

#### Scenario: Focused tests cover storage lifecycle behavior

- **WHEN** this change is implemented
- **THEN** focused tests SHALL cover managed path rebase, legacy secure-storage migration, stale workspace reconciliation, and local sync safety after rebase
