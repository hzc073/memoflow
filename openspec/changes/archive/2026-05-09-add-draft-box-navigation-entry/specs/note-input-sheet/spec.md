## ADDED Requirements

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
