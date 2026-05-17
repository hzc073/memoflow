## ADDED Requirements

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
