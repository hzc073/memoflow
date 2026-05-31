## ADDED Requirements

### Requirement: Clipboard URL clipping SHALL be retryable after a completed share flow

The system SHALL allow a clipboard-detected URL clipping attempt to be followed by a newly copied URL after the current share flow completes, fails, or is canceled, without requiring app restart or a background/foreground lifecycle transition.

#### Scenario: User copies a different URL after a clipping failure
- **WHEN** the app has prompted for clipboard URL A
- **AND** the user confirms clipping
- **AND** the clipping flow reaches a failed or canceled terminal state
- **AND** the user copies clipboard URL B while the app remains foregrounded
- **THEN** the app SHALL schedule a new bounded clipboard check after the share flow releases ownership
- **AND** the app SHALL prompt for URL B when URL B is a supported clipping candidate.

#### Scenario: User copies a different URL after successful clipping
- **WHEN** the app has prompted for clipboard URL A
- **AND** the user completes the clipping flow successfully
- **AND** the user copies clipboard URL B while the app remains foregrounded
- **THEN** the app SHALL be able to detect URL B on the post-share clipboard check
- **AND** the app SHALL NOT require the user to restart, switch workspaces, or background and resume the app.

#### Scenario: Same clipboard URL is not repeatedly prompted
- **WHEN** the app has already prompted for clipboard URL A
- **AND** the share flow releases ownership
- **AND** the clipboard still contains URL A
- **THEN** the post-share clipboard check SHALL NOT show another prompt for URL A.

#### Scenario: Active share flow still suppresses clipboard checks
- **WHEN** a clipboard-detected share flow or desktop share task is still active
- **THEN** clipboard URL checks SHALL remain suppressed
- **AND** the app SHALL NOT interrupt the active share flow with a second clipboard prompt.

### Requirement: Clipboard retry scheduling SHALL remain bounded and lifecycle-owned

Clipboard-share retry behavior SHALL use explicit lifecycle/share-flow release events and bounded delayed checks rather than continuous foreground polling.

#### Scenario: Share flow releases ownership
- **WHEN** the current share flow transitions to a terminal state
- **AND** no other active desktop share task remains
- **THEN** the app SHALL schedule a bounded clipboard detection burst
- **AND** the burst SHALL reuse the same eligibility checks for preferences, workspace availability, duplicate URL suppression, and active-flow suppression as ordinary clipboard detection.

#### Scenario: Clipboard candidate is unsupported or unavailable
- **WHEN** a post-share clipboard check reads an unsupported URL, empty clipboard text, or an unavailable clipboard
- **THEN** the app SHALL skip prompting
- **AND** the app SHALL NOT enter a share-flow-active state.

### Requirement: Clipboard retry implementation SHALL preserve architecture boundaries

Clipboard-share retry policy SHALL be implemented through existing app/startup/share coordination seams and MUST NOT move reusable share-flow lifecycle policy into UI widgets.

#### Scenario: Share UI remains presentation-focused
- **WHEN** clipboard retry behavior is implemented
- **THEN** share UI widgets SHALL NOT own global clipboard retry scheduling
- **AND** share UI widgets SHALL NOT directly read the app clipboard to decide whether to reopen clipping.

#### Scenario: API compatibility is unchanged
- **WHEN** clipboard retry behavior is implemented
- **THEN** Memos server API request/response models, route adapters, and version compatibility behavior SHALL remain unchanged.
