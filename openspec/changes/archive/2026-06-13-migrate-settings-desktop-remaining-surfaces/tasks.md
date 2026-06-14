## 1. 准备与边界确认

- [x] 1.1 读取 `desktop_shortcuts_overview_screen.dart`、`desktop_settings_window_app.dart`、settings UI seam、drift guardrail 和 focused desktop settings tests。
- [x] 1.2 运行 `openspec validate migrate-settings-desktop-remaining-surfaces --strict`。
- [x] 1.3 确认本 change 不修改 desktop lifecycle、method channel routing、workspace refresh、API files、private hooks 或 commercial logic。

## 2. Runtime migration

- [x] 2.1 将 `DesktopShortcutsOverviewScreen` root 迁移到 `SettingsPage`，保留 shortcut label construction、editor/global grouping 和 list ordering。
- [x] 2.2 将 shortcut overview group/row helpers 改用 settings tokens / `ColorScheme`，移除 direct `MemoFlowPalette` 和 direct `Scaffold`。
- [x] 2.3 将 `desktop_settings_window_app.dart` 中 sidebar nav tile direct palette 使用迁移到 `ColorScheme` 或 settings/platform tokens。
- [x] 2.4 保留 `MemoFlowPalette.applyThemeColor(...)` composition-root theme apply，不改 `MaterialApp` theme setup。

## 3. Guardrails and tests

- [x] 3.1 更新 `settings_ui_drift_guardrail_test.dart`，将 `desktop_shortcuts_overview_screen.dart` 移入 `migratedFiles`，并为 `desktop_settings_window_app.dart` 添加仅允许 `palette: 1` 的窄例外。
- [x] 3.2 运行或更新 focused desktop settings window / shortcut overview tests，确认 F1/shortcut overview route 和 pane navigation behavior preserved。
- [x] 3.3 运行 settings drift guardrail 和 modularity guardrail。

## 4. Verification

- [x] 4.1 运行 `openspec validate migrate-settings-desktop-remaining-surfaces --strict`。
- [x] 4.2 运行 focused desktop settings/shortcut tests。
- [x] 4.3 运行 `flutter test test/architecture/settings_ui_drift_guardrail_test.dart --reporter expanded`。
- [x] 4.4 运行 `flutter test test/architecture/modularity_dependency_guardrail_test.dart --reporter expanded`。
- [x] 4.5 运行 `flutter analyze`。
- [x] 4.6 记录验证结果、剩余 guardrail 例外和风险。
