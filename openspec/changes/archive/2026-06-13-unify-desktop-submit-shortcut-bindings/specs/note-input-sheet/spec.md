## ADDED Requirements

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
