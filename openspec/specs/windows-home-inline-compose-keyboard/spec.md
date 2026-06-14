## Purpose

Define Windows desktop home wide-layout keyboard ownership between the inline compose editor and selected memo preview navigation.
## Requirements
### Requirement: Home inline compose owns plain Enter while focused

On Windows desktop home wide layout, the home inline compose editor SHALL own plain `Enter` while its multiline text editor is focused. The memo list MUST NOT interpret that same key press as a command to open the currently selected preview memo.

#### Scenario: Plain Enter inserts a line break instead of opening selected memo

- **GIVEN** the app is running in Windows desktop wide layout
- **AND** a memo has been selected for the right-side preview pane
- **AND** the home inline compose `TextField` is focused
- **WHEN** the user presses plain `Enter`
- **THEN** the app does not open `MemoDetailScreen` for the selected memo
- **AND** the inline compose editor accepts the key press as multiline editing input

#### Scenario: Preview selection remains available while composing

- **GIVEN** the app is running in Windows desktop wide layout
- **AND** a memo has been selected for the right-side preview pane
- **WHEN** the user focuses the home inline compose editor
- **THEN** the preview pane may remain visible
- **AND** the selected memo state MUST NOT cause plain `Enter` in the focused editor to navigate away from the editor

### Requirement: Selected memo Enter navigation remains available outside editors

On Windows desktop home wide layout, the memo list SHALL preserve plain `Enter` navigation for the selected preview memo when no text editor owns keyboard input.

#### Scenario: Plain Enter opens selected memo when editor is not focused

- **GIVEN** the app is running in Windows desktop wide layout
- **AND** a memo has been selected for the right-side preview pane
- **AND** the home inline compose editor is not focused
- **WHEN** the user presses plain `Enter`
- **THEN** the app opens `MemoDetailScreen` for the selected memo

### Requirement: Selected memo can be deselected by clicking it again

On Windows desktop home wide layout, the memo list SHALL allow the user to cancel the current memo selection by clicking the already-selected memo card again. This deselect action MUST clear the selected memo keyboard target and hide the preview pane that depends on that selected memo.

#### Scenario: Clicking selected memo clears selection

- **GIVEN** the app is running in Windows desktop wide layout
- **AND** a memo card is selected for the right-side preview pane
- **WHEN** the user clicks the same selected memo card again
- **THEN** the memo card is no longer rendered as selected
- **AND** the selected memo no longer acts as the target for plain `Enter`
- **AND** the right-side preview pane is hidden or no longer displays the deselected memo

#### Scenario: Deselect preserves inline compose state

- **GIVEN** the app is running in Windows desktop wide layout
- **AND** the home inline compose editor contains draft text
- **AND** a memo card is selected for the right-side preview pane
- **WHEN** the user clicks the same selected memo card again
- **THEN** the current inline compose draft text remains available
- **AND** the deselect action does not submit, clear, or close the inline compose editor

### Requirement: Inline compose publish shortcuts remain unchanged

The fix SHALL NOT change existing home inline compose publish or formatting shortcuts. Shortcut arbitration MUST continue to route configured editor shortcuts to the inline composer while it is active.

#### Scenario: Shift Enter publish fallback remains editor-owned

- **GIVEN** the app is running in Windows desktop wide layout
- **AND** a memo has been selected for the right-side preview pane
- **AND** the home inline compose editor is focused and contains submittable content
- **WHEN** the user presses `Shift+Enter`
- **THEN** the key press follows the existing inline compose publish fallback behavior
- **AND** the app does not open `MemoDetailScreen` for the selected memo

### Requirement: Desktop shortcut fix preserves architecture boundaries

The Windows home inline compose keyboard fix SHALL preserve existing dependency boundaries and MUST NOT introduce new reverse dependencies from lower layers into feature UI code.

#### Scenario: No new lower layer dependency on memo features

- **WHEN** the fix is implemented
- **THEN** `state`, `application`, and `core` layers do not add new imports from `features/memos`
- **AND** shortcut behavior remains owned by the existing `features/memos` screen/delegate seam or a same-layer helper

### Requirement: Preview close clears selected memo target
On Windows desktop layouts that support the home right-side preview pane, closing the visible preview pane SHALL clear the selected memo target. The closed preview pane MUST NOT leave the previously previewed memo selected for card highlight, plain `Enter` navigation, or selected-memo shortcuts.

#### Scenario: Escape closes preview and clears selection
- **GIVEN** the app is running in Windows desktop wide layout
- **AND** a memo card is selected for the right-side preview pane
- **AND** the right-side preview pane is visible
- **WHEN** the user presses `Escape`
- **THEN** the right-side preview pane is hidden
- **AND** the memo card is no longer rendered as selected
- **AND** the selected memo no longer acts as the target for plain `Enter`

#### Scenario: Preview close button clears selection
- **GIVEN** the app is running in a Windows desktop layout that supports the right-side preview pane
- **AND** a memo card is selected for the right-side preview pane
- **AND** the right-side preview pane is visible
- **WHEN** the user clicks the preview pane close button
- **THEN** the right-side preview pane is hidden
- **AND** the memo card is no longer rendered as selected
- **AND** the selected memo no longer acts as the target for plain `Enter`

#### Scenario: Preview toolbar toggle clears selection when closing
- **GIVEN** the app is running in a Windows desktop layout that supports the right-side preview pane
- **AND** a memo card is selected for the right-side preview pane
- **AND** the right-side preview pane is visible
- **WHEN** the user activates the desktop preview toolbar toggle to close preview
- **THEN** the right-side preview pane is hidden
- **AND** the memo card is no longer rendered as selected
- **AND** the selected memo no longer acts as the target for plain `Enter`

#### Scenario: Closing preview preserves inline compose state
- **GIVEN** the app is running in Windows desktop wide layout
- **AND** the home inline compose editor contains draft text
- **AND** a memo card is selected for the right-side preview pane
- **AND** the right-side preview pane is visible
- **WHEN** the user closes the right-side preview pane
- **THEN** the current inline compose draft text remains available
- **AND** the close action does not submit, clear, or close the inline compose editor

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

