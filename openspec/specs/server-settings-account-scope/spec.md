# server-settings-account-scope Specification

## Purpose
TBD - created by archiving change fix-server-settings-account-scope. Update Purpose after archive.
## Requirements
### Requirement: Server settings state is scoped to the active workspace identity
The system SHALL scope server settings load state, displayed values, and save actions to the current active remote account or local-library identity.

#### Scenario: Remote account switch reloads server settings
- **WHEN** the active remote account changes while `ServerSettingsScreen` or `serverSettingsProvider` is still alive
- **THEN** the previous account's server settings snapshot SHALL NOT remain as the active editable state
- **AND** the next server settings load SHALL use the new active account's `MemosApi` context

#### Scenario: API context change refreshes server settings
- **WHEN** the active account's server API context changes, including account key, base URL, token, server version override, or legacy API override
- **THEN** server settings state SHALL be rebuilt or reloaded for that new API context
- **AND** version-specific settings routes SHALL be selected from the new context

#### Scenario: Local library switch clears remote server settings
- **WHEN** the active workspace changes from a remote account to local-library mode
- **THEN** the system SHALL NOT send server settings API requests
- **AND** the server settings state SHALL present server settings as unavailable for local-library mode

### Requirement: Server settings saves use the same identity as the active state
The system SHALL prevent stale server settings snapshots from being saved against a different active account.

#### Scenario: Save after account switch targets the new account
- **WHEN** the user switches from account A to account B and then saves a server setting
- **THEN** the save request SHALL use account B's current `MemosApi` context
- **AND** account A's previously displayed snapshot SHALL NOT be used as editable input for account B

#### Scenario: In-flight load completion cannot revive stale state
- **WHEN** a server settings load for account A completes after the active identity has changed to account B
- **THEN** the account A result SHALL NOT overwrite account B's active server settings state

### Requirement: Server settings account scoping preserves module boundaries
The system SHALL implement account/workspace scoping in the state/provider boundary without moving server settings logic into widgets.

#### Scenario: Screen renders scoped provider state
- **WHEN** `ServerSettingsScreen` needs to display or save a server setting
- **THEN** it SHALL use the scoped server settings provider/controller
- **AND** it SHALL NOT construct account-specific `MemosApi` instances or version-specific routes directly

#### Scenario: Regression coverage protects account scope
- **WHEN** tests simulate switching from one remote account to another
- **THEN** they SHALL verify that stale server settings values are not reused
- **AND** they SHALL verify that save requests target the current account context

