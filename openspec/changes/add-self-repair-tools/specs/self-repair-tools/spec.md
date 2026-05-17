## ADDED Requirements

### Requirement: Feedback provides a self-repair entry
The system SHALL expose user-triggered local repair tools from the settings feedback/support area.

#### Scenario: User opens self repair from feedback
- **WHEN** the user opens `Settings -> Feedback`
- **THEN** the feedback page SHALL provide a self-repair entry
- **AND** activating the entry SHALL open a dedicated self-repair page
- **AND** the entry SHALL NOT immediately mutate local data

### Requirement: Self-repair page offers explicit local maintenance actions
The system SHALL show repair actions as explicit user-triggered operations rather than a broad database reset.

#### Scenario: User views available repair actions
- **WHEN** the self-repair page is displayed
- **THEN** it SHALL offer separate actions for abnormal tag cleanup, local keyword search index rebuild, and stats cache rebuild
- **AND** it SHALL explain that these operations repair local derived data
- **AND** it SHALL NOT offer a full local database reset in this change

#### Scenario: Repair action is confirmed before mutation
- **WHEN** the user starts a repair action that mutates local derived data
- **THEN** the system SHALL ask for confirmation before running the operation
- **AND** the confirmation SHALL name the affected derived data
- **AND** cancellation SHALL leave local data unchanged

### Requirement: Abnormal tag cleanup recomputes stored tags from memo content
The system SHALL provide a user-triggered abnormal tag cleanup action that recomputes persisted memo tags from memo content using the current shared tag extraction and reconciliation rules.

#### Scenario: Historical code-context false positive is cleaned
- **GIVEN** an existing memo has a persisted tag that only appears inside a Markdown code context
- **WHEN** the user confirms abnormal tag cleanup
- **THEN** the false tag SHALL be removed from `memo_tags`
- **AND** it SHALL be removed from redundant `memos.tags`
- **AND** local search and stats data SHALL no longer expose the false tag after repair-dependent refresh completes
- **AND** valid tags in user-visible memo prose SHALL remain persisted

#### Scenario: Strict recompute policy is visible
- **WHEN** the abnormal tag cleanup confirmation is shown
- **THEN** the system SHALL explain that memo tags will be rebuilt from current memo body `#tag` text
- **AND** it SHALL explain that stored tags not present in the memo body may be removed

### Requirement: Search index rebuild restores local keyword search data
The system SHALL provide a user-triggered search index rebuild action for local keyword search persistence.

#### Scenario: User rebuilds local search index
- **WHEN** the user confirms local keyword search index rebuild
- **THEN** the system SHALL rebuild local search persistence used for literal keyword search
- **AND** memo content, memo metadata, accounts, preferences, attachments, and remote server data SHALL NOT be deleted by this action

#### Scenario: Search semantics are preserved after rebuild
- **WHEN** local keyword search index rebuild completes
- **THEN** memo search SHALL continue to use the existing literal substring matching contract
- **AND** existing state, tag, date range, advanced filter, ordering, and result-limit behavior SHALL remain constraints on visible results

### Requirement: Stats cache rebuild restores derived statistics
The system SHALL provide a user-triggered stats cache rebuild action for local statistics derived from memo data.

#### Scenario: User rebuilds stats cache
- **WHEN** the user confirms stats cache rebuild
- **THEN** the system SHALL rebuild derived local statistics including heatmap data, tag statistics, and summary counters
- **AND** memo content, memo metadata, accounts, preferences, attachments, and remote server data SHALL NOT be deleted by this action

### Requirement: Self-repair reports operation state
The system SHALL provide clear operation state for self-repair actions.

#### Scenario: Repair action is running
- **WHEN** a self-repair action is running
- **THEN** the page SHALL show a busy state for that action
- **AND** it SHOULD prevent starting conflicting repair actions until the current action finishes

#### Scenario: Repair action succeeds
- **WHEN** a self-repair action completes successfully
- **THEN** the page SHALL show a localized success result naming the completed repair
- **AND** app-visible derived data SHALL refresh through existing change notification behavior

#### Scenario: Repair action fails
- **WHEN** a self-repair action fails
- **THEN** the page SHALL show a localized recoverable error state
- **AND** the user SHALL remain able to export logs or use the existing feedback/reporting path

### Requirement: Self-repair preserves modular boundaries
The system MUST implement self-repair orchestration through reusable state/application and data-layer seams rather than embedding maintenance logic in settings widgets.

#### Scenario: UI routes user intent only
- **WHEN** self-repair UI code is added or changed
- **THEN** it MUST only render localized copy, confirmations, operation state, and user actions
- **AND** it MUST NOT import focused DB persistence helpers such as `MemoSearchDbPersistence` or `TagDbPersistence`
- **AND** it MUST NOT manually duplicate tag, search, or stats rebuild sequences

#### Scenario: Repair service uses approved database facade
- **WHEN** a self-repair action runs
- **THEN** it MUST call a state/application service or mutation seam that uses approved `AppDatabase` facade methods
- **AND** `AppDatabase` SHALL remain responsible for desktop write-proxy dispatch, public maintenance facade compatibility, and data-change notification policy

#### Scenario: No reverse dependency is introduced
- **WHEN** self-repair tools are implemented during `evolve_modularity`
- **THEN** the implementation MUST NOT introduce new `state -> features`, `application -> features`, or `core -> state|application|features` imports
