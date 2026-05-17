## ADDED Requirements

### Requirement: Memo detail long-press opens an anchored action popover
The system SHALL open a memo detail action popover anchored to the user's long-press position when the current memo detail surface allows actions.

#### Scenario: User long-presses blank space below a short memo
- **GIVEN** an editable normal memo is open in the memo detail view
- **AND** the rendered memo content does not fill the visible detail body
- **WHEN** the user long-presses the blank body area below the memo content
- **THEN** the system SHALL show a floating action popover near the long-press position
- **AND** the popover SHALL use the same visual language as the home memo card more menu

#### Scenario: User long-presses an eligible memo detail content area
- **GIVEN** an editable normal memo is open in the memo detail view
- **WHEN** the user long-presses a non-control region of the memo detail content
- **THEN** the system SHALL show the detail action popover near the long-press position
- **AND** the current double-tap edit behavior SHALL remain available

### Requirement: Memo detail action availability follows memo state
The system SHALL expose detail popover actions according to the memo state and the detail surface editability.

#### Scenario: Normal editable memo detail menu is shown
- **GIVEN** an editable normal memo is open in the memo detail view
- **WHEN** the detail action popover opens
- **THEN** copy, edit, reminder, pin or unpin, add to collection, archive, adjust time, view history, and delete SHALL be available
- **AND** delete SHALL be visually separated as a destructive action

#### Scenario: Archived memo detail menu is shown
- **GIVEN** an archived memo is open in the memo detail view
- **WHEN** the detail action popover opens
- **THEN** copy, view history, restore, and delete SHALL be available
- **AND** normal-only actions such as edit, reminder, pin or unpin, add to collection, archive, and adjust time SHALL NOT be shown
- **AND** delete SHALL remain visually separated as a destructive action

#### Scenario: Read-only memo detail is shown
- **GIVEN** a memo is open in a read-only detail surface
- **WHEN** the user long-presses the detail body
- **THEN** the system SHALL NOT expose mutating detail actions from the long-press menu

### Requirement: Detail popover action selection preserves existing behavior
The system SHALL route selected detail popover actions through existing detail action handlers or existing mutation seams, and the popover MUST NOT directly perform memo mutations.

#### Scenario: User selects an action
- **GIVEN** the detail action popover is open
- **WHEN** the user selects an available action
- **THEN** the popover SHALL close
- **AND** the selected action SHALL run through the same behavior path as the corresponding existing detail or memo action
- **AND** the selected action SHALL be emitted exactly once

#### Scenario: User dismisses without selecting
- **GIVEN** the detail action popover is open
- **WHEN** the user taps outside the popover or uses a platform dismissal path
- **THEN** the popover SHALL close
- **AND** no memo action SHALL be emitted

### Requirement: Detail long-press preserves child interactions
The system SHALL preserve existing interactions for child controls inside the memo detail body when adding the long-press action menu.

#### Scenario: User interacts with an image, media item, link, task, audio row, attachment row, or error-panel button
- **GIVEN** the memo detail body contains an interactive child control
- **WHEN** the user performs that child control's existing gesture
- **THEN** the child control SHALL continue to handle its existing behavior
- **AND** the detail action popover SHALL NOT replace that child behavior

#### Scenario: Selectable text handles selection
- **GIVEN** selectable memo text is rendered in the memo detail body
- **WHEN** the text selection system claims a long-press gesture
- **THEN** text selection SHALL continue to work
- **AND** the detail action popover SHALL NOT break selection behavior

### Requirement: Detail popover positioning remains viewport-safe
The system SHALL keep the memo detail action popover fully visible within the current overlay viewport when space allows.

#### Scenario: Long-press occurs near a viewport edge
- **GIVEN** an editable memo detail view is visible
- **WHEN** the user long-presses near the top, right, bottom, or left edge of the viewport
- **THEN** the popover SHALL clamp or shift so its content remains visible within the viewport
