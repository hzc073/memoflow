# note-input-sheet Specification

## Purpose
Define the note input sheet compose surface, including compact and full-screen presentation, draft behavior, and architecture boundaries.
## Requirements
### Requirement: Note input sheet renders only intentional handles
The note input sheet SHALL render only intentional sheet chrome. It MUST NOT render a secondary bottom handle or decorative bar between the compose toolbar area and the system keyboard.

#### Scenario: Keyboard opens for note input
- **WHEN** the user taps the primary compose `+` action on Android and `NoteInputSheet` opens with the text field focused
- **THEN** the area immediately above the system keyboard does not show an extra horizontal decorative bar from `NoteInputSheet`

#### Scenario: Top sheet handle remains visible
- **WHEN** `NoteInputSheet` is displayed
- **THEN** the sheet may show a single top drag handle that communicates the bottom-sheet surface

### Requirement: Note input sheet visual cleanup preserves existing compose behavior
The note input sheet visual cleanup SHALL NOT change compose behavior, data flow, or architecture boundaries.

#### Scenario: Compose controls remain available
- **WHEN** the full-screen writing presentation is added
- **THEN** the editor, compose toolbar, attachment controls, visibility controls, location controls, voice/send behavior, draft behavior, and submit behavior remain available through the compact and/or full-screen presentations

#### Scenario: No new architecture dependency is introduced
- **WHEN** the full-screen writing presentation is implemented
- **THEN** the change does not introduce new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies

### Requirement: Note input sheet supports full-screen writing
The note input sheet SHALL provide a full-screen writing presentation for add-memo composition while preserving the existing compact bottom-sheet presentation.

#### Scenario: User expands from compact sheet
- **GIVEN** `NoteInputSheet` is open in compact bottom-sheet mode
- **WHEN** the user activates the embedded full-screen control in the sheet header area
- **THEN** the compose UI switches to full-screen writing mode
- **AND** the existing draft text, attachments, linked memos, location, visibility, pending media, and focus target are preserved

#### Scenario: Full-screen mode maximizes editor area
- **GIVEN** `NoteInputSheet` is open in full-screen writing mode
- **THEN** the UI does not show a title such as `Create memo` in the header
- **AND** the header left area is used for first-row toolbar actions
- **AND** collapse and close controls remain available on the header right
- **AND** a second compact toolbar row appears below the header
- **AND** the editor occupies the remaining available area below the toolbar section

#### Scenario: Full-screen send remains compact
- **GIVEN** `NoteInputSheet` is open in full-screen writing mode
- **THEN** the send control is presented as a lightweight toolbar control near the visibility control
- **AND** it does not use the large compact-sheet floating send/voice button treatment

#### Scenario: User collapses full-screen mode
- **GIVEN** `NoteInputSheet` is open in full-screen writing mode
- **WHEN** the user activates the collapse full-screen control
- **THEN** the compose UI returns to compact bottom-sheet mode
- **AND** the current compose content and metadata are preserved

#### Scenario: User closes full-screen mode
- **GIVEN** `NoteInputSheet` is open in full-screen writing mode with unsaved content
- **WHEN** the user activates the close control
- **THEN** the sheet uses the same draft-aware close behavior as compact mode

### Requirement: Note input sheet keeps presentation separate from compose behavior
`NoteInputSheet` SHALL remain the presentation entry point for note composition, but reusable compose behavior SHALL be owned by focused helpers, controllers, coordinators, or services outside the screen widget.

#### Scenario: Presentation widgets receive state and callbacks
- **WHEN** compact or full-screen note input UI is rendered after the decoupling
- **THEN** feature-local presentation widgets SHALL receive render state and callbacks rather than directly owning draft persistence, attachment staging, deferred media processing, memo mutation, or sync orchestration

#### Scenario: Shared behavior is not hidden in the screen file
- **WHEN** compose behavior is needed by note input and another compose surface or share flow
- **THEN** the reusable behavior SHALL live in a stable helper, controller, coordinator, provider, or application service instead of being available only inside `note_input_sheet.dart`

### Requirement: Note input decoupling preserves existing compose behavior
The note input decoupling SHALL preserve current compact and full-screen compose behavior while moving responsibilities to smaller owners.

#### Scenario: Presentation mode toggles preserve compose state
- **WHEN** the user switches between compact and full-screen note input
- **THEN** text, selection, focus target, attachments, linked memos, location, visibility, deferred media progress, and draft identity SHALL remain intact

#### Scenario: Submit behavior remains equivalent
- **WHEN** the user submits from compact or full-screen note input after decoupling
- **THEN** memo content, tags, visibility, location, relations, attachments, pending uploads, deferred inline image handling, local save toast behavior, and best-effort sync behavior SHALL match the pre-decoupling submit path

#### Scenario: Draft behavior remains equivalent
- **WHEN** the note input sheet is closed, restored from draft box, or cleared after submit
- **THEN** compose draft persistence, legacy note draft persistence, active draft selection, attachment preservation, and inline image source mappings SHALL match the pre-decoupling behavior

### Requirement: Note input decoupling improves touched modularity hotspots
While the project remains in `evolve_modularity`, note input decoupling SHALL leave touched architecture hotspots equal or better structured and SHALL NOT expand reverse-dependency allowlists.

#### Scenario: Tag autocomplete reverse dependency is removed
- **WHEN** reusable tag query or suggestion logic is extracted from note input UI
- **THEN** `state/memos/memo_composer_controller.dart` SHALL NOT import `features/memos/tag_autocomplete.dart`
- **AND** the corresponding `state -> features` guardrail allowlist entry SHALL be removed or tightened

#### Scenario: Lower layers avoid note input UI dependencies
- **WHEN** note input compose, draft, submit, or attachment logic is moved into `state`, `application`, or `core`
- **THEN** those lower-layer modules SHALL NOT import `features/memos/note_input_sheet.dart` or feature presentation widgets

#### Scenario: Shared attachment and MIME logic has stable owners
- **WHEN** MIME resolution, pending attachment staging requests, or deferred share media preparation is reused outside `NoteInputSheet`
- **THEN** the shared logic SHALL be owned by dependency-free helpers or state/application services with focused tests rather than duplicated in screen files

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

### Requirement: Note input can launch from a selected compose draft
The note input sheet SHALL support being opened with a selected compose draft id and SHALL restore that draft through the existing draft restoration behavior.

#### Scenario: Note input restores selected draft content
- **GIVEN** a saved compose draft exists
- **WHEN** `NoteInputSheet` is opened with that draft id
- **THEN** the editor displays the draft content
- **AND** the note input sheet tracks the draft as the active draft

#### Scenario: Note input restores selected draft metadata
- **GIVEN** a saved compose draft includes visibility, attachments, linked memos, location, or inline image source mappings
- **WHEN** `NoteInputSheet` is opened with that draft id
- **THEN** the note input sheet restores the supported non-text draft state through the existing draft restore path
- **AND** subsequent draft save or submit behavior continues to target the selected draft record

#### Scenario: Missing selected draft does not crash note input
- **GIVEN** `NoteInputSheet` is opened with a draft id that no longer exists
- **WHEN** the note input sheet finishes initialization
- **THEN** the app does not crash
- **AND** the note input sheet remains usable as a normal compose surface

#### Scenario: Existing Draft Box picker behavior remains unchanged
- **GIVEN** an already-open note input surface opens Draft Box from its compose toolbar
- **WHEN** the user selects a draft
- **THEN** the existing in-place draft restoration behavior remains available
- **AND** the toolbar-launched picker does not require navigation through the sidebar or bottom navigation shell

#### Scenario: No new architecture dependency is introduced
- **WHEN** selected-draft note input launch support is implemented
- **THEN** the change does not introduce new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies
- **AND** full draft restoration remains backed by existing note input draft helper behavior

### Requirement: Desktop note input SHALL use configured submit shortcut

When `NoteInputSheet` is running on a desktop shortcut platform, it SHALL use the configured `DesktopShortcutAction.publishMemo` binding as the direct submit/send shortcut for the active note input editor.

#### Scenario: Configured submit binding sends note input content

- **GIVEN** `NoteInputSheet` is open on Windows or macOS
- **AND** the note input editor is focused and contains submittable content
- **AND** `DesktopShortcutAction.publishMemo` has a configured binding
- **WHEN** 用户按下配置的 `publishMemo` 快捷键
- **THEN** `NoteInputSheet` SHALL invoke its existing submit-or-voice path for text submission
- **AND** it SHALL preserve existing draft cleanup, attachment, visibility, location, toast, and sync behavior

#### Scenario: Plain Enter remains note input editing input

- **GIVEN** `NoteInputSheet` is open on a desktop shortcut platform
- **AND** the note input editor is focused
- **WHEN** 用户按下 plain `Enter`
- **THEN** `NoteInputSheet` SHALL keep existing multiline or smart-enter editing behavior
- **AND** it SHALL NOT submit/send solely because plain `Enter` was pressed

#### Scenario: Full-screen and compact modes share submit binding

- **GIVEN** `NoteInputSheet` can switch between compact and full-screen compose modes
- **AND** `DesktopShortcutAction.publishMemo` has a configured binding
- **WHEN** 用户按下配置的 submit shortcut in either presentation mode while the editor is focused
- **THEN** the same configured binding SHALL submit/send content in both modes
- **AND** switching presentation modes SHALL NOT reset or reinterpret the configured shortcut binding

#### Scenario: No new architecture dependency is introduced

- **WHEN** desktop note input submit shortcut behavior is implemented
- **THEN** the change SHALL NOT introduce new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies
- **AND** reusable shortcut matching SHALL remain in the desktop shortcut seam or a dependency-free helper
