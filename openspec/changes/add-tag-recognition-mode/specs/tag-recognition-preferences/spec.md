## ADDED Requirements

### Requirement: Workspace tag recognition policy preference
The system SHALL provide a workspace-scoped tag recognition policy preference that controls app-visible tag extraction, rendering, autocomplete, search filtering, and local maintenance behavior for the active memo library.

#### Scenario: New workspace defaults to MemoFlow strict
- **WHEN** a new workspace or local library preferences record is created without a stored tag recognition policy
- **THEN** the system SHALL default that new record to `memoflowStrict`

#### Scenario: Existing workspace preserves strict behavior
- **WHEN** an existing workspace preferences JSON has no stored `tagRecognitionPolicy`
- **THEN** the system SHALL interpret that workspace as `memoflowStrict`
- **AND** upgrading the app SHALL NOT silently make existing memo body inline hashtags visible as tags

#### Scenario: Stored policy round trips
- **WHEN** workspace preferences are saved with `memoflowStrict`, `memosCompatible`, or a supported `custom` policy
- **THEN** reloading preferences SHALL restore the same resolved policy
- **AND** invalid or unknown stored values SHALL fall back to `memoflowStrict`

#### Scenario: Memos connection and import do not prompt for policy changes
- **WHEN** the user first connects to a Memos backend, imports Memos data, or imports third-party memo content
- **THEN** the system SHALL NOT prompt the user to switch to `memosCompatible`
- **AND** it SHALL NOT silently change the stored tag recognition policy
- **AND** imported or synced memo visible tags SHALL be interpreted using the current workspace policy

### Requirement: Preferences UI exposes tag recognition rules
The system SHALL expose the tag recognition policy from preferences using a localized settings row, preset/custom selection UI, and explanatory tip dialogs.

#### Scenario: User views recognition policy row
- **WHEN** the user opens preferences for a workspace
- **THEN** the page SHALL show a `Tag recognition rules` setting or localized equivalent
- **AND** the row SHALL show the current policy label
- **AND** activating the row SHALL let the user choose between `MemoFlow strict`, `Memos compatible`, and `Custom`

#### Scenario: User opens recognition tip
- **WHEN** the user taps the tip icon beside the tag recognition setting title
- **THEN** the system SHALL show a centered dialog explaining the preset policies and the custom option
- **AND** the dialog SHALL include examples showing that `今天记录 #生活` is recognized only under the Memos compatible policy or a custom policy that enables inline body tags
- **AND** the dialog SHALL include examples showing that `#生活` at the start or end tag zone is recognized under the MemoFlow strict policy
- **AND** dismissing the dialog SHALL NOT change the selected policy

### Requirement: Custom policy options explain each recognition choice
The system SHALL provide an info dialog beside every user-configurable custom tag recognition option, with shared policy impact guidance shown at the custom settings level.

#### Scenario: User opens a custom option tip
- **WHEN** the user opens the info dialog for any custom recognition option
- **THEN** the system SHALL show a centered dialog titled with that option's localized label
- **AND** the dialog SHALL explain what text positions or token types that option affects
- **AND** it SHALL include at least one recognized example and one not-recognized or cautionary example when applicable
- **AND** it SHALL describe the option in user-facing language rather than parser terminology

#### Scenario: Custom policy shared impact is explained once
- **WHEN** the user opens custom tag recognition settings
- **THEN** the system SHALL state that rendering, autocomplete, search filtering, and local repair follow the resulting resolved policy
- **AND** it SHALL state that existing memo indexes require explicit recompute to immediately reflect changed rules

#### Scenario: Custom option without tip is invalid
- **WHEN** a custom recognition option is added to the settings UI
- **THEN** that option MUST include an associated localized info dialog title and body
- **AND** focused UI or localization tests SHOULD fail if the option is reachable without explanatory dialog content

### Requirement: Policy changes offer explicit local recompute
The system SHALL treat policy changes as preference changes first, then offer an explicit user-triggered recompute for existing derived tag data.

#### Scenario: User changes policy and accepts recompute
- **WHEN** the user changes the workspace tag recognition policy
- **AND** the user confirms the recompute prompt
- **THEN** the system SHALL persist the new policy
- **AND** it SHALL rebuild local memo tag mappings, redundant tag text, search index, and statistics using the selected policy
- **AND** it SHALL prune orphan local tag rows after the recompute

#### Scenario: User changes policy and skips recompute
- **WHEN** the user changes the workspace tag recognition policy
- **AND** the user cancels or skips the recompute prompt
- **THEN** the system SHALL keep the new preference value
- **AND** it SHALL NOT immediately mutate existing memo tag mappings, search index, or statistics as part of that cancellation
- **AND** future memo writes and explicit maintenance SHALL use the new policy

#### Scenario: Recompute is local maintenance
- **WHEN** policy-switch recompute runs
- **THEN** it SHALL only update local derived data
- **AND** it SHALL NOT edit memo content, account credentials, sync queues, backups, remote server data, or commercial/private-extension state
