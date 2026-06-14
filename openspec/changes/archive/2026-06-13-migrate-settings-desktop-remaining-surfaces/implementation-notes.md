## Summary

本批完成 settings UI drift guardrail 中剩余 desktop settings surfaces 的迁移。`DesktopShortcutsOverviewScreen` 已迁入 `SettingsPage` / `SettingsSection`，`DesktopSettingsWindowApp` 的 sidebar nav tile direct palette 使用已迁到 `ThemeData.colorScheme`。未修改 desktop lifecycle、method channel routing、workspace refresh、target routing、API files、private hooks 或 commercial logic。

## Runtime Changes

- `DesktopShortcutsOverviewScreen`:
  - root 从 direct `Scaffold` 迁移到 `SettingsPage`。
  - editor/global shortcut 分组使用 `SettingsSection`。
  - row 文本颜色来自 `settingsPageTokens`。
  - 保留 `normalizeDesktopShortcutBindings`、action label、editor/global grouping、F1 fallback label 和 shortcut binding label construction。
- `DesktopSettingsWindowApp`:
  - workbench text muted/main color改用 `ColorScheme.onSurface` / `onSurfaceVariant`。
  - `_DesktopPaneNavTile` selected/hover/foreground colors 改用 `ColorScheme.primary` / `onSurfaceVariant`。
  - 保留 `MemoFlowPalette.applyThemeColor(...)`，因为这是独立 settings window `MaterialApp` 的 composition-root theme apply。

## Guardrails

- `settings_ui_drift_guardrail_test.dart` 已将：
  - `desktop_shortcuts_overview_screen.dart`
  - `desktop_settings_window_app.dart`
  加入 `migratedFiles`。
- `desktop_settings_window_app.dart` 有且仅有 `palette: 1` 窄例外，用于 composition-root `MemoFlowPalette.applyThemeColor(...)`。
- Drift pattern 扫描结果只剩上述 theme apply 例外。

## Verification

- `openspec validate migrate-settings-desktop-remaining-surfaces --strict` passed.
- `flutter test test/architecture/settings_ui_drift_guardrail_test.dart --reporter expanded` passed.
- `flutter test test/features/settings/desktop_settings_window_app_test.dart --reporter expanded` passed.
- `flutter test test/architecture/modularity_dependency_guardrail_test.dart --reporter expanded` passed.
- `flutter analyze` passed.

## Remaining Risk

- Full `flutter test` was not run in this pass.
- `MemoFlowPalette.applyThemeColor(...)` remains as documented composition-root exception; guardrail now prevents other direct palette usage in `desktop_settings_window_app.dart`.
