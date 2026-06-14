## ADDED Requirements

### Requirement: Home inline compose SHALL own configured submit shortcut while focused

On Windows desktop home wide layout, the home inline compose editor SHALL own the configured `DesktopShortcutAction.publishMemo` binding while its multiline text editor is focused. This configured submit shortcut SHALL submit/send the inline compose content and SHALL NOT be interpreted as selected memo navigation.

#### Scenario: Configured submit binding publishes inline compose

- **GIVEN** the app is running in Windows desktop wide layout
- **AND** a memo has been selected for the right-side preview pane
- **AND** the home inline compose editor is focused and contains submittable content
- **AND** `DesktopShortcutAction.publishMemo` has a configured binding
- **WHEN** 用户按下配置的 `publishMemo` 快捷键
- **THEN** the key press SHALL invoke the inline compose submit path
- **AND** the app SHALL NOT open `MemoDetailScreen` for the selected memo

#### Scenario: Shift Enter fallback remains editor-owned

- **GIVEN** the app is running in Windows desktop wide layout
- **AND** a memo has been selected for the right-side preview pane
- **AND** the home inline compose editor is focused and contains submittable content
- **WHEN** 用户按下 `Shift+Enter`
- **THEN** the key press SHALL follow the existing inline compose publish fallback behavior
- **AND** selected memo navigation SHALL NOT run

#### Scenario: Plain Enter remains line-break input

- **GIVEN** the app is running in Windows desktop wide layout
- **AND** the home inline compose editor is focused
- **WHEN** 用户按下 plain `Enter`
- **THEN** the key press SHALL remain multiline editing input
- **AND** it SHALL NOT submit inline compose content
- **AND** it SHALL NOT open the selected memo
