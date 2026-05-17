# server-settings Specification

## Purpose
TBD - created by archiving change add-server-settings-entry. Update Purpose after archive.
## Requirements
### Requirement: Server settings entry is separate from user general settings
The system SHALL expose backend-wide limit controls through a standalone `服务器设置` entry rather than through `UserGeneralSettingsScreen`.

#### Scenario: Remote account sees server settings entry
- **WHEN** the current workspace has an authenticated Memos account
- **THEN** the account and security settings screen SHALL show a `服务器设置` entry near `用户通用设置`
- **AND** activating the entry SHALL open the server settings screen

#### Scenario: User general settings remain user-scoped
- **WHEN** the user opens `用户通用设置`
- **THEN** the screen SHALL continue to manage only `UserSetting.GENERAL` fields such as locale and default memo visibility
- **AND** the screen SHALL NOT render memo content length or attachment upload capacity controls

#### Scenario: Local library has no server settings backend
- **WHEN** the active workspace is a local library without a remote Memos account
- **THEN** the system SHALL NOT send server settings API requests
- **AND** any reachable server settings surface SHALL present the settings as unavailable for local-library mode

### Requirement: Server settings load version-specific backend limits
The system SHALL load memo content length and attachment upload limits using the active Memos server version family.

#### Scenario: Memos 0.21 server settings
- **WHEN** the active remote server is resolved as Memos `0.21`
- **THEN** the system SHALL read attachment upload capacity from `GET api/v1/status` using `maxUploadSizeMiB`
- **AND** the system SHALL mark memo content length editing as unsupported because the reference backend uses hardcoded memo length limits

#### Scenario: Memos 0.22 through 0.24 server settings
- **WHEN** the active remote server is resolved as Memos `0.22`, `0.23`, or `0.24`
- **THEN** the system SHALL read memo content length from `GET api/v1/workspace/settings/MEMO_RELATED` using `memoRelatedSetting.contentLengthLimit`
- **AND** the system SHALL read attachment upload capacity from `GET api/v1/workspace/settings/STORAGE` using `storageSetting.uploadSizeLimitMb`

#### Scenario: Memos 0.25 plus server settings
- **WHEN** the active remote server is resolved as Memos `0.25` or newer
- **THEN** the system SHALL read memo content length from `GET api/v1/instance/settings/MEMO_RELATED` using `memoRelatedSetting.contentLengthLimit`
- **AND** the system SHALL read attachment upload capacity from `GET api/v1/instance/settings/STORAGE` using `storageSetting.uploadSizeLimitMb`

#### Scenario: Unknown server flavor uses modern instance settings
- **WHEN** the active remote server flavor cannot be resolved
- **THEN** the system SHALL attempt the Memos `0.25+` instance settings routes
- **AND** the system SHALL classify missing or incompatible endpoints as unavailable rather than presenting false values

### Requirement: Server settings expose per-field availability and permission state
The system SHALL track support, value, editability, source, and unavailable reason separately for memo content length and attachment upload capacity.

#### Scenario: Storage setting read is permission denied
- **WHEN** reading `STORAGE` returns HTTP `401` or `403`
- **THEN** the attachment upload capacity field SHALL be marked as permission denied
- **AND** the corresponding edit control SHALL be disabled

#### Scenario: Memo setting read succeeds while storage read fails
- **WHEN** reading `MEMO_RELATED` succeeds but reading `STORAGE` fails
- **THEN** the screen SHALL display the memo content length value
- **AND** the screen SHALL display attachment upload capacity as unavailable without discarding the successful memo value

#### Scenario: Backend returns invalid or non-positive limits
- **WHEN** the backend returns a malformed, missing, zero, or negative limit value
- **THEN** the affected field SHALL be marked unavailable with an invalid response or non-positive limit reason
- **AND** the system SHALL NOT present the invalid value as editable server truth

### Requirement: Server settings update supported limits safely
The system SHALL update only supported server limit fields with positive integer values and SHALL reflect the server-confirmed value after saving.

#### Scenario: Update Memos 0.22 through 0.24 memo limit
- **WHEN** the user saves a positive memo content length limit on a Memos `0.22`, `0.23`, or `0.24` server
- **THEN** the system SHALL update `api/v1/workspace/settings/MEMO_RELATED`
- **AND** the saved value SHALL target `memoRelatedSetting.contentLengthLimit`

#### Scenario: Update Memos 0.25 plus attachment limit
- **WHEN** the user saves a positive attachment upload capacity on a Memos `0.25` or newer server
- **THEN** the system SHALL update `api/v1/instance/settings/STORAGE`
- **AND** the saved value SHALL target `storageSetting.uploadSizeLimitMb`

#### Scenario: Save is rejected by backend permission
- **WHEN** a server settings update returns HTTP `401` or `403`
- **THEN** the system SHALL show the setting as not editable for the current account
- **AND** the system SHALL keep the previously displayed value unless a refresh returns a different server value

#### Scenario: Invalid local input is not sent
- **WHEN** the user enters an empty, non-numeric, zero, or negative limit
- **THEN** the system SHALL reject the input locally
- **AND** the system SHALL NOT send a server settings update request

### Requirement: Server settings updates preserve sibling backend fields
The system SHALL preserve unrelated fields in structured backend settings when updating one limit value.

#### Scenario: Updating storage upload limit preserves storage configuration
- **WHEN** the system updates `storageSetting.uploadSizeLimitMb`
- **THEN** the update request SHALL include the existing storage setting fields that are not being changed
- **AND** fields such as storage type, filepath template, and S3 configuration SHALL NOT be intentionally cleared by the client

#### Scenario: Updating memo content limit preserves memo-related policy fields
- **WHEN** the system updates `memoRelatedSetting.contentLengthLimit`
- **THEN** the update request SHALL include the existing memo-related setting fields that are not being changed
- **AND** fields such as display-with-update-time, reactions, comments, and related policy toggles SHALL NOT be intentionally cleared by the client

### Requirement: Server settings implementation preserves module boundaries
The system SHALL keep server settings version routing, response parsing, permission classification, and merge-before-update behavior outside UI widgets.

#### Scenario: Server settings screen renders provider state
- **WHEN** `ServerSettingsScreen` needs to display or update a limit
- **THEN** it SHALL use a state/provider boundary for loading and mutation
- **AND** it SHALL NOT construct version-specific API routes directly in the widget

#### Scenario: API compatibility logic remains in the data layer
- **WHEN** the implementation maps Memos versions to server settings routes
- **THEN** that mapping SHALL live in the Memos API/data layer
- **AND** no new `state -> features`, `application -> features`, or `core -> state|application|features` dependency SHALL be introduced by this change

