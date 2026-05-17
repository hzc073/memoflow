## ADDED Requirements

### Requirement: Full-screen note input uses bottom toolbar layout
The note input sheet full-screen compose presentation SHALL place compose toolbar actions at the bottom of the full-screen surface while reserving the top chrome for close and collapse controls.

#### Scenario: Full-screen top chrome shows close and collapse controls
- **GIVEN** `NoteInputSheet` is open in full-screen compose mode
- **THEN** the top-left chrome area exposes a close control
- **AND** the top-right chrome area exposes a collapse control that returns to compact bottom-sheet mode
- **AND** the top chrome does not contain `MemoToolbarRow.top` or `MemoToolbarRow.bottom` compose actions
- **AND** the full-screen header does not show a title such as `Create memo`

#### Scenario: Full-screen top chrome avoids system status bar
- **GIVEN** `NoteInputSheet` is opened through its modal bottom-sheet entry on a device with a top system inset
- **WHEN** the user expands to full-screen compose mode
- **THEN** the full-screen top chrome is laid out below the system status bar inset
- **AND** the close and collapse controls remain fully tappable

#### Scenario: Full-screen expansion opens the editor keyboard
- **GIVEN** `NoteInputSheet` is open in compact bottom-sheet mode and the editor is not focused
- **WHEN** the user expands to full-screen compose mode
- **THEN** the full-screen editor receives focus
- **AND** the text input keyboard is requested automatically

#### Scenario: Full-screen expansion reopens keyboard from an already-focused sheet editor
- **GIVEN** `NoteInputSheet` is open in compact bottom-sheet mode
- **AND** the compact editor has already owned focus through the shared editor focus node
- **WHEN** the user expands to full-screen compose mode
- **THEN** the full-screen editor receives focus
- **AND** the old compact editor text input connection is reset
- **AND** the full-screen editor becomes the active text input client so typed keyboard input updates the full-screen editor

#### Scenario: Full-screen toolbar rows appear at the bottom
- **GIVEN** `NoteInputSheet` is open in full-screen compose mode
- **THEN** the bottom toolbar area exposes visible `MemoToolbarRow.top` actions as the first toolbar row
- **AND** the bottom toolbar area exposes visible `MemoToolbarRow.bottom` actions as the second toolbar row
- **AND** toolbar actions continue to follow `MemoToolbarPreferences`

#### Scenario: Full-screen right rail stacks visibility and send
- **GIVEN** `NoteInputSheet` is open in full-screen compose mode
- **THEN** the bottom toolbar right side presents the visibility control above the lightweight send/voice control
- **AND** the send/voice control uses the compact full-screen 30px treatment
- **AND** the send/voice control does not use the large compact-sheet floating send button treatment

### Requirement: Full-screen note input layout preserves compose behavior
The note input sheet full-screen bottom toolbar adjustment SHALL NOT change compose state ownership, submit behavior, draft behavior, visibility behavior, or dependency boundaries.

#### Scenario: Collapse returns to compact sheet without losing compose state
- **GIVEN** `NoteInputSheet` is open in full-screen compose mode with draft text or compose metadata
- **WHEN** the user activates the collapse control
- **THEN** the compose UI returns to compact bottom-sheet mode
- **AND** the current text, selection, attachments, linked memos, location, visibility, pending media, and tag autocomplete state remain preserved

#### Scenario: Close uses existing draft-aware behavior
- **GIVEN** `NoteInputSheet` is open in full-screen compose mode with unsaved content
- **WHEN** the user activates the top-left close control
- **THEN** the sheet uses the same draft-aware close behavior as compact bottom-sheet mode

#### Scenario: Submit and visibility behavior remain unchanged
- **GIVEN** `NoteInputSheet` is open in full-screen compose mode
- **WHEN** the user activates the bottom toolbar send/voice control
- **THEN** the action follows the existing note input submit-or-voice path
- **WHEN** the user activates the bottom toolbar visibility control
- **THEN** the action opens the existing visibility selection flow

#### Scenario: No new architecture dependency is introduced
- **WHEN** the full-screen bottom toolbar adjustment is implemented
- **THEN** the change does not introduce new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies
- **AND** compose action construction remains backed by existing `MemoComposeToolbarActionSpec` and `MemoToolbarPreferences` paths
