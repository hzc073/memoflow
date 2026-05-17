## ADDED Requirements

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
- **WHEN** the bottom legacy handle is removed
- **THEN** the editor, compose toolbar, attachment controls, visibility controls, location controls, voice/send button, draft behavior, and submit behavior remain unchanged

#### Scenario: No new architecture dependency is introduced
- **WHEN** the note input sheet visual cleanup is implemented
- **THEN** the change does not introduce new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies
