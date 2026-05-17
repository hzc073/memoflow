## MODIFIED Requirements

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
