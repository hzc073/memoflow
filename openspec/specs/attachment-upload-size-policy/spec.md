# attachment-upload-size-policy Specification

## Purpose
TBD - created by archiving change auto-save-xiaohongshu-share-media-attachments. Update Purpose after archive.
## Requirements
### Requirement: Attachment upload size limit is resolved from the active workspace
The system SHALL resolve attachment upload size limits according to the active workspace mode and Memos server version.

#### Scenario: Local library has no Memos backend pre-limit
- **WHEN** the active workspace is a local library without a remote Memos account
- **THEN** the system SHALL treat the attachment upload size limit as unknown for client pre-check purposes
- **AND** the system SHALL NOT apply the Memos backend default 30 MiB limit as a hard local-library limit

#### Scenario: Memos 0.21 limit is read from system status
- **WHEN** the active remote server is resolved as Memos `0.21`
- **THEN** the system SHALL attempt to read `maxUploadSizeMiB` from `GET api/v1/status`
- **AND** a positive `maxUploadSizeMiB` value SHALL be converted to bytes for attachment limit decisions

#### Scenario: Memos 0.22 through 0.24 limit is read from workspace storage setting
- **WHEN** the active remote server is resolved as Memos `0.22`, `0.23`, or `0.24`
- **THEN** the system SHALL attempt to read `storageSetting.uploadSizeLimitMb` from `GET api/v1/workspace/settings/STORAGE`
- **AND** a positive `uploadSizeLimitMb` value SHALL be converted to bytes for attachment limit decisions

#### Scenario: Memos 0.25 plus limit is read from instance storage setting
- **WHEN** the active remote server is resolved as Memos `0.25` or newer
- **THEN** the system SHALL attempt to read `storageSetting.uploadSizeLimitMb` from `GET api/v1/instance/settings/STORAGE`
- **AND** a positive `uploadSizeLimitMb` value SHALL be converted to bytes for attachment limit decisions

### Requirement: Unknown attachment size limits do not become hard client blocks
The system SHALL treat unreadable or unavailable backend limits as unknown and SHALL NOT substitute a hardcoded 30 MiB client block.

#### Scenario: Storage setting requires elevated permission
- **WHEN** the backend storage setting request fails with an authentication or permission response such as HTTP 401 or HTTP 403
- **THEN** the system SHALL classify the attachment upload size limit as unknown
- **AND** the system SHALL allow attachment upload or sync to proceed until the server accepts or rejects it

#### Scenario: Storage setting endpoint is unavailable
- **WHEN** the backend storage setting request fails because the endpoint is missing, unsupported, malformed, or temporarily unavailable
- **THEN** the system SHALL classify the attachment upload size limit as unknown
- **AND** the system SHALL NOT reject a selected or downloaded attachment solely because the client could not read the limit

### Requirement: Known attachment size limits guide video compression and pre-checks
The system SHALL use known backend attachment size limits to guide video compression, client pre-check behavior, and user-facing size-limit messages.

#### Scenario: Known limit triggers compression planning
- **WHEN** a downloaded video attachment is larger than a known backend upload size limit
- **THEN** the system SHALL offer or run the configured video compression path before enqueueing the attachment
- **AND** the compression target SHALL be derived from the known limit with a conservative margin rather than from a fixed 30 MiB constant

#### Scenario: Known limit is shown in compression confirmation
- **WHEN** a downloaded video attachment is larger than a known backend upload size limit
- **THEN** the compression confirmation copy SHALL communicate the resolved known limit
- **AND** the confirmation copy MUST NOT mention a hardcoded 30 MB or 30 MiB limit unless the resolved known limit is actually 30 MiB

#### Scenario: Compression output remains above known limit
- **WHEN** video compression completes but the output remains larger than the known backend upload size limit
- **THEN** the system SHALL avoid enqueueing that oversized remote upload as if it were valid
- **AND** the system SHALL surface or record a media attachment failure for that video
- **AND** the user-facing failure copy SHALL communicate the resolved known limit instead of a hardcoded 30 MB value

### Requirement: Server upload rejection remains authoritative
The system SHALL rely on server-side upload rejection when the client cannot know every effective attachment size limit.

#### Scenario: Server rejects attachment as too large
- **WHEN** an attachment upload fails with HTTP 413 or an equivalent backend error such as `file size exceeds the limit`
- **THEN** the system SHALL classify the sync failure as an attachment-too-large failure
- **AND** the user-facing sync error SHALL preserve enough detail to explain that the server rejected the attachment size

#### Scenario: Reverse proxy limit is lower than Memos setting
- **WHEN** a reverse proxy or hosting layer rejects an upload even though the Memos API limit was unknown or higher
- **THEN** the system SHALL treat the server/proxy response as authoritative
- **AND** the system SHALL NOT assume the Memos `uploadSizeLimitMb` value is the only possible upload limit

### Requirement: Attachment upload policy reflects server settings updates
The system SHALL keep attachment upload pre-check behavior consistent with successful edits made from the `服务器设置` screen.

#### Scenario: Successful attachment limit update refreshes upload policy
- **WHEN** the user successfully updates the attachment upload capacity from `服务器设置`
- **THEN** subsequent attachment upload pre-checks SHALL use the updated server-confirmed limit
- **AND** stale cached upload size values SHALL NOT continue to drive compression or oversized-file decisions

#### Scenario: Failed attachment limit update does not change upload policy
- **WHEN** an attachment upload capacity update fails because of permission, unsupported endpoint, invalid input, or request failure
- **THEN** the existing attachment upload pre-check policy SHALL remain unchanged
- **AND** the system SHALL NOT substitute the failed requested value as a known backend limit

#### Scenario: Unreadable storage setting remains unknown for upload pre-checks
- **WHEN** `服务器设置` cannot read the backend `STORAGE` setting
- **THEN** attachment upload pre-checks SHALL continue to classify the backend upload size limit as unknown
- **AND** the system SHALL NOT introduce a hardcoded client block solely because the server settings screen could not read the limit

### Requirement: Attachment storage setting parsing is shared outside widgets
The system SHALL keep attachment storage limit parsing and permission classification in API or state-layer code rather than duplicating it inside settings widgets.

#### Scenario: Server settings screen displays attachment capacity
- **WHEN** the server settings screen displays attachment upload capacity
- **THEN** it SHALL consume parsed provider or API model state
- **AND** it SHALL NOT parse raw `STORAGE` response maps directly in the widget

#### Scenario: Upload pre-checks and server settings share compatible classification
- **WHEN** a storage setting response is permission denied, malformed, missing, or non-positive
- **THEN** both upload pre-checks and server settings SHALL classify the condition compatibly
- **AND** the implementation SHALL avoid divergent duplicate parsing logic that would make one surface treat the value as known while the other treats it as unknown

