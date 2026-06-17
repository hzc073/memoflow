## ADDED Requirements

### Requirement: Workspace tag recognition mode preference
The system SHALL provide a workspace-scoped tag recognition mode preference that controls app-visible tag extraction, rendering, autocomplete, search filtering, and local maintenance behavior for the active memo library.

#### Scenario: New workspace defaults to Memos compatible
- **WHEN** a new workspace or local library preferences record is created without a stored tag recognition mode
- **THEN** the system SHALL default that new record to `memosCompatible`

#### Scenario: Existing workspace preserves strict behavior
- **WHEN** an existing workspace preferences JSON has no stored `tagRecognitionMode`
- **THEN** the system SHALL interpret that workspace as `memoflowStrict`
- **AND** upgrading the app SHALL NOT silently make existing memo body inline hashtags visible as tags

#### Scenario: Stored mode round trips
- **WHEN** workspace preferences are saved with `memosCompatible` or `memoflowStrict`
- **THEN** reloading preferences SHALL restore the same mode
- **AND** invalid or unknown stored values SHALL fall back to a safe supported mode

### Requirement: Preferences UI exposes tag recognition rules
The system SHALL expose the tag recognition mode from preferences using a localized settings row and a centered explanatory tip dialog.

#### Scenario: User views recognition mode row
- **WHEN** the user opens preferences for a workspace
- **THEN** the page SHALL show a `Tag recognition rules` setting or localized equivalent
- **AND** the row SHALL show the current mode label
- **AND** activating the row SHALL let the user choose between `Memos compatible` and `Strict tag zone`

#### Scenario: User opens recognition tip
- **WHEN** the user taps the tip icon beside the tag recognition setting title
- **THEN** the system SHALL show a centered dialog explaining both modes
- **AND** the dialog SHALL include examples showing that `今天记录 #生活` is recognized only in Memos compatible mode
- **AND** the dialog SHALL include examples showing that `#生活` at the start or end tag zone is recognized in strict mode
- **AND** dismissing the dialog SHALL NOT change the selected mode

### Requirement: Mode changes offer explicit local recompute
The system SHALL treat mode changes as preference changes first, then offer an explicit user-triggered recompute for existing derived tag data.

#### Scenario: User changes mode and accepts recompute
- **WHEN** the user changes the workspace tag recognition mode
- **AND** the user confirms the recompute prompt
- **THEN** the system SHALL persist the new mode
- **AND** it SHALL rebuild local memo tag mappings, redundant tag text, search index, and statistics using the selected mode
- **AND** it SHALL prune orphan local tag rows after the recompute

#### Scenario: User changes mode and skips recompute
- **WHEN** the user changes the workspace tag recognition mode
- **AND** the user cancels or skips the recompute prompt
- **THEN** the system SHALL keep the new preference value
- **AND** it SHALL NOT immediately mutate existing memo tag mappings, search index, or statistics as part of that cancellation
- **AND** future memo writes and explicit maintenance SHALL use the new mode

#### Scenario: Recompute is local maintenance
- **WHEN** mode-switch recompute runs
- **THEN** it SHALL only update local derived data
- **AND** it SHALL NOT edit memo content, account credentials, sync queues, backups, remote server data, or commercial/private-extension state
