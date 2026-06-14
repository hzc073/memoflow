## Why

完成 `migrate-settings-ai-pages` 后，`settings_ui_drift_guardrail_test.dart` 的剩余 settings UI allowlist 只保留 `desktop_settings_window_app.dart` 和 `desktop_shortcuts_overview_screen.dart`。其中 `desktop_shortcuts_overview_screen.dart` 是普通设置子页，仍有 direct `Scaffold`、direct `MemoFlowPalette` 和 page-local group/card styling；`desktop_settings_window_app.dart` 是桌面设置窗口 workbench/routing shell，仍有侧栏 nav tile 的 direct palette 使用。

本 change 收敛这些剩余 settings desktop surfaces 的 visual drift，让 guardrail 能区分真正的主题 composition root 例外和需要迁移的页面视觉逻辑。

## What Changes

- 将 `DesktopShortcutsOverviewScreen` 迁移到 `SettingsPage`、`SettingsSection`、settings tokens 或等价 settings/platform seams。
- 将 `DesktopSettingsWindowApp` 中侧栏 nav tile 的 direct `MemoFlowPalette` 使用迁移到 `ThemeData.colorScheme` / settings tokens。
- 更新 `settings_ui_drift_guardrail_test.dart`，把 `desktop_shortcuts_overview_screen.dart` 移入 `migratedFiles`，并为 `desktop_settings_window_app.dart` 只保留 `MemoFlowPalette.applyThemeColor(...)` 这一 composition-root 例外。
- 保留 desktop settings window target routing、workspace snapshot refresh、多窗口通信、settings pane navigation、keyboard shortcut overview opening 和 window lifecycle behavior。

## Non-Goals

- 不修改 desktop settings window lifecycle、main-window method channel、workspace reload、AI target routing、close-to-menu-bar policy 或 macOS/window-manager behavior。
- 不迁移非 settings runtime files，不修改 API files、private hooks 或 commercial logic。
- 不实现新的 shortcut customization 功能；只迁移快捷键总览的视觉 seam。

## Impact

- Affected runtime files:
  - `memos_flutter_app/lib/features/settings/desktop_shortcuts_overview_screen.dart`
  - `memos_flutter_app/lib/features/settings/desktop_settings_window_app.dart`
- Affected guardrail/tests:
  - `memos_flutter_app/test/architecture/settings_ui_drift_guardrail_test.dart`
  - Existing desktop settings window / shortcut focused tests as needed.
- Capability delta:
  - `platform-adaptive-ui-system`: remaining desktop settings surfaces SHALL use settings/platform visual seams with a narrow composition-root exception.
