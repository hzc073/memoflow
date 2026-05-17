## ADDED Requirements

### Requirement: Android memo editors restore keyboard after app resume
On Android, memo editing surfaces SHALL restore the system text input keyboard after the app resumes when the same editor had focus and the keyboard was visible before the app moved to the background.

#### Scenario: Compact note input resumes keyboard
- **GIVEN** `NoteInputSheet` is open in compact compose mode on Android
- **AND** the compact editor is focused
- **AND** the system keyboard is visible
- **WHEN** the user switches to another app and then returns to MemoFlow
- **THEN** the compact editor remains focused
- **AND** the system keyboard is requested again after resume

#### Scenario: Full-screen note input resumes keyboard
- **GIVEN** `NoteInputSheet` is open in full-screen compose mode on Android
- **AND** the full-screen editor is focused
- **AND** the system keyboard is visible
- **WHEN** the user switches to another app and then returns to MemoFlow
- **THEN** the note input sheet remains in full-screen compose mode
- **AND** the full-screen editor remains the active editor
- **AND** the system keyboard is requested again after resume

#### Scenario: Memo editor resumes keyboard
- **GIVEN** `MemoEditorScreen` is open on Android
- **AND** its editor is focused
- **AND** the system keyboard is visible
- **WHEN** the user switches to another app and then returns to MemoFlow
- **THEN** the memo editor remains focused
- **AND** the system keyboard is requested again after resume

#### Scenario: Home inline compose resumes keyboard
- **GIVEN** the home inline compose editor is visible on Android
- **AND** the inline compose editor is focused
- **AND** the system keyboard is visible
- **WHEN** the user switches to another app and then returns to MemoFlow
- **THEN** the inline compose editor remains focused
- **AND** the system keyboard is requested again after resume

### Requirement: Android keyboard resume is conservative
The keyboard resume behavior MUST NOT open the keyboard unless the same memo editing surface was actively using the keyboard before backgrounding and remains eligible after resume.

#### Scenario: Keyboard hidden before background does not reopen
- **GIVEN** a supported memo editing surface is visible on Android
- **AND** its editor has focus
- **AND** the system keyboard is not visible
- **WHEN** the app backgrounds and resumes
- **THEN** the system keyboard is not requested solely because the editor has focus

#### Scenario: Unfocused editor does not reopen keyboard
- **GIVEN** a supported memo editing surface is visible on Android
- **AND** its editor is not focused
- **WHEN** the app backgrounds and resumes
- **THEN** the system keyboard is not requested for that editor

#### Scenario: Covered route must still be current
- **GIVEN** a supported memo editing surface had focus and visible keyboard before backgrounding on Android
- **WHEN** the app resumes with another route, dialog, or blocking surface above that editor
- **THEN** the hidden editor does not request the system keyboard

#### Scenario: Non-Android platforms are unchanged
- **GIVEN** a supported memo editing surface is used on iOS, Windows, macOS, Linux, or web
- **WHEN** the app lifecycle changes
- **THEN** this Android keyboard resume behavior does not request the system keyboard

### Requirement: Android keyboard resume preserves memo editing state
The keyboard resume behavior SHALL NOT change memo content, selection, presentation mode, draft identity, attachments, linked memos, location, visibility, or submit behavior.

#### Scenario: Resume preserves note input compose state
- **GIVEN** `NoteInputSheet` has draft text, selection, attachments, linked memos, location, or visibility state on Android
- **WHEN** the app backgrounds and resumes while the keyboard resume behavior runs
- **THEN** the existing note input compose state is preserved
- **AND** no memo is submitted, cleared, or saved solely because the keyboard is restored

#### Scenario: Resume preserves memo editor state
- **GIVEN** `MemoEditorScreen` has edited content or pending attachment changes on Android
- **WHEN** the app backgrounds and resumes while the keyboard resume behavior runs
- **THEN** the existing editor state is preserved
- **AND** no save, discard, or draft mutation is triggered solely because the keyboard is restored

#### Scenario: Resume preserves inline compose state
- **GIVEN** the home inline compose editor has draft content or compose metadata on Android
- **WHEN** the app backgrounds and resumes while the keyboard resume behavior runs
- **THEN** the inline compose state is preserved
- **AND** no submit, clear, or draft-box action is triggered solely because the keyboard is restored

### Requirement: Android keyboard resume preserves architecture boundaries
The Android memo keyboard resume implementation SHALL keep lifecycle restoration policy in a feature-local seam or equally stable owner and MUST NOT introduce new reverse dependencies from lower layers into memo feature UI.

#### Scenario: Shared lifecycle policy is not duplicated across screens
- **WHEN** Android keyboard resume behavior is implemented for note input, memo editor, and home inline compose
- **THEN** the shared restore-intent and post-resume keyboard request policy is owned by a reusable helper, controller, or equivalent feature-local seam
- **AND** the same policy is not independently reimplemented in each screen body

#### Scenario: No lower-layer dependency regression
- **WHEN** Android keyboard resume behavior is implemented
- **THEN** `state`, `application`, and `core` layers do not add new imports from `features/memos`
- **AND** `app.dart` does not become responsible for deciding which memo editor should restore the keyboard
