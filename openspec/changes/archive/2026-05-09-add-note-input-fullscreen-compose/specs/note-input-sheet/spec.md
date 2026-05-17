## MODIFIED Requirements

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

### Requirement: Note input sheet visual cleanup preserves existing compose behavior
The note input sheet visual cleanup SHALL NOT change compose behavior, data flow, or architecture boundaries.

#### Scenario: Compose controls remain available
- **WHEN** the full-screen writing presentation is added
- **THEN** the editor, compose toolbar, attachment controls, visibility controls, location controls, voice/send behavior, draft behavior, and submit behavior remain available through the compact and/or full-screen presentations

#### Scenario: No new architecture dependency is introduced
- **WHEN** the full-screen writing presentation is implemented
- **THEN** the change does not introduce new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies
