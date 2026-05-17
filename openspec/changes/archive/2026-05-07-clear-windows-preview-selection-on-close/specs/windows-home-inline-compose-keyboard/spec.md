## ADDED Requirements

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
