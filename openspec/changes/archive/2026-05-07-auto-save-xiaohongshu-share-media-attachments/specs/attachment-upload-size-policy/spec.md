## ADDED Requirements

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
The system SHALL use known backend attachment size limits to guide video compression and client pre-check behavior.

#### Scenario: Known limit triggers compression planning
- **WHEN** a downloaded video attachment is larger than a known backend upload size limit
- **THEN** the system SHALL offer or run the configured video compression path before enqueueing the attachment
- **AND** the compression target SHALL be derived from the known limit with a conservative margin rather than from a fixed 30 MiB constant

#### Scenario: Compression output remains above known limit
- **WHEN** video compression completes but the output remains larger than the known backend upload size limit
- **THEN** the system SHALL avoid enqueueing that oversized remote upload as if it were valid
- **AND** the system SHALL surface or record a media attachment failure for that video

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
