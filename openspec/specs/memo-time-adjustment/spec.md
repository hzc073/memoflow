# memo-time-adjustment Specification

## Purpose
TBD - created by archiving change support-edit-memo-create-time. Update Purpose after archive.
## Requirements
### Requirement: Memo time adjustment entry points
The system SHALL provide an editable memo-level action for adjusting an existing memo's time without placing that action in the list floating action stack or Markdown formatting toolbar.

#### Scenario: Open adjustment from memo card menu
- **WHEN** an editable normal memo's card action menu is opened
- **THEN** the menu SHALL include an "Adjust time" action near the existing edit action

#### Scenario: Archived or read-only memo does not expose editing action
- **WHEN** a memo is archived or the current memo surface is read-only
- **THEN** the system SHALL NOT expose a time adjustment action that can mutate the memo

#### Scenario: Detail view exposes same capability without top-level clutter
- **WHEN** an editable normal memo is opened in detail view
- **THEN** the system SHALL provide access to the same time adjustment surface without adding a new always-visible AppBar icon

### Requirement: Time adjustment surface
The system SHALL show a dedicated time adjustment surface that lets the user choose a date and time for the memo and clearly communicates that the change affects timeline display/order.

#### Scenario: Surface shows current memo time
- **WHEN** the user opens the time adjustment surface
- **THEN** the surface SHALL initialize its date and time fields from the memo's current effective display time

#### Scenario: User cancels adjustment
- **WHEN** the user dismisses or cancels the time adjustment surface
- **THEN** the memo's local timestamp fields SHALL remain unchanged

#### Scenario: User saves valid adjustment
- **WHEN** the user selects a valid date and time and confirms the adjustment
- **THEN** the system SHALL save the selected timestamp as the memo's adjusted time

### Requirement: Local timestamp consistency
The system SHALL persist a confirmed memo time adjustment locally in a way that keeps creation-time semantics and visible timeline ordering consistent.

#### Scenario: Adjusted time updates visible timestamp
- **WHEN** the user saves a new time for a memo
- **THEN** the memo list and detail surfaces SHALL display the selected timestamp for that memo

#### Scenario: Adjusted time updates timeline ordering
- **WHEN** the user saves a new time that changes the memo's relative timeline position
- **THEN** memo list ordering and date-range reads based on the effective memo time SHALL reflect the selected timestamp

#### Scenario: Adjusted time updates creation and display fields
- **WHEN** the user saves a new time for a memo
- **THEN** local persistence SHALL update both the memo creation timestamp and display timestamp to the selected value

### Requirement: Timestamp sync behavior
The system SHALL enqueue and process remote sync for memo time adjustments using existing memo mutation and outbox ownership seams.

#### Scenario: Timestamp payload is queued
- **WHEN** a synced remote-backed memo's time is adjusted and remote sync is allowed
- **THEN** the system SHALL enqueue an `update_memo` outbox task containing explicit creation and display timestamp values

#### Scenario: Supported remote timestamp update
- **WHEN** an outbox timestamp update is processed for a server that supports creation-time updates
- **THEN** the remote update SHALL include both creation and display timestamp values

#### Scenario: Unsupported remote creation-time update
- **WHEN** an outbox timestamp update cannot be fully applied because the server rejects creation-time updates
- **THEN** the system SHALL preserve the local adjusted time and surface sync failure or fallback state through existing sync-state/error behavior instead of silently discarding the adjustment

### Requirement: Boundary preservation
The system SHALL implement memo time adjustment without introducing new reverse dependencies or leaking write logic into UI widgets.

#### Scenario: UI delegates mutation
- **WHEN** the time adjustment surface confirms a selected timestamp
- **THEN** feature UI SHALL delegate the write to a state-layer memo mutation seam rather than writing directly to SQLite or server APIs

#### Scenario: Lower layers remain UI-independent
- **WHEN** the time adjustment implementation is complete
- **THEN** `state`, `application`, and `core` layers SHALL NOT gain new imports from `features/memos`

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
