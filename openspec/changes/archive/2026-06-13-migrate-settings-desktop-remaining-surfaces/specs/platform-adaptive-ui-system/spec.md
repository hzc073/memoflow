## ADDED Requirements

### Requirement: Remaining desktop settings surfaces SHALL use settings/platform visual seams

Remaining desktop settings surfaces SHALL render normal settings pages and sidebar visual states through `SettingsPage`, `SettingsSection`, `settingsPageTokens`, `ThemeData.colorScheme`, or equivalent settings/platform seams, while preserving desktop window composition-root behavior.

#### Scenario: Desktop shortcut overview is migrated

- **GIVEN** the user opens `DesktopShortcutsOverviewScreen`
- **WHEN** editor and global shortcut groups render
- **THEN** the page SHALL use settings semantic page/section seams or equivalent settings tokens
- **AND** shortcut labels, fallback F1 label, editor/global grouping, and binding normalization SHALL be preserved.

#### Scenario: Desktop settings window sidebar uses theme tokens

- **GIVEN** the desktop settings window workbench renders pane navigation
- **WHEN** selected and unselected pane nav tiles are displayed
- **THEN** visual state colors SHALL come from `ThemeData.colorScheme` or equivalent platform/settings tokens
- **AND** pane switching, target routing, workspace reload, method channel handling, and window lifecycle behavior SHALL be preserved.

#### Scenario: Composition-root palette apply remains narrowly allowed

- **GIVEN** `DesktopSettingsWindowApp` builds its independent `MaterialApp`
- **WHEN** user theme preferences are applied
- **THEN** `MemoFlowPalette.applyThemeColor(...)` MAY remain as a narrow composition-root exception
- **AND** guardrails SHALL NOT allow additional direct `MemoFlowPalette` usage in `desktop_settings_window_app.dart`.
