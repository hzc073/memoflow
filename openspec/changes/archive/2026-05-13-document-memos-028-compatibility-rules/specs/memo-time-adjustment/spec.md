## ADDED Requirements

### Requirement: Remote time adjustment honors Memos 0.28 timestamp API
The system SHALL sync memo time adjustments to Memos `0.28.x` using only timestamp fields supported by the server API.

#### Scenario: Memos 0.28 update avoids display_time
- **WHEN** a memo time adjustment is synced to a Memos `0.28.x` server
- **THEN** the remote update request SHALL NOT include `display_time` in `updateMask`
- **AND** the remote update request SHALL NOT include a `displayTime` body field

#### Scenario: Supported timestamp fields may still sync
- **WHEN** a memo time adjustment is synced to a Memos `0.28.x` server and a supported timestamp field is required
- **THEN** the remote update request SHALL use only Memos `0.28.x` supported timestamp fields such as `create_time` or `update_time`

#### Scenario: Local adjusted time is not discarded
- **WHEN** a Memos `0.28.x` server cannot represent the app's local display-time metadata as a remote `display_time`
- **THEN** the system SHALL preserve the local adjusted time and SHALL NOT silently reset local timeline ordering

#### Scenario: Timestamp compatibility is covered by tests
- **WHEN** memo time adjustment or API route compatibility tests run for Memos `0.28.x`
- **THEN** they MUST fail if the client sends removed `display_time` or `displayTime` fields
