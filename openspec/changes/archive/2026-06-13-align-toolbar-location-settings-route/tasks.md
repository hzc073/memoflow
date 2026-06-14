## 1. Navigation Seam

- [x] 1.1 新增 settings-owned location settings opener（例如 `features/settings/location_settings_navigation.dart` 或等价 seam），桌面优先调用 `openDesktopSettingsWindow(target: DesktopSettingsWindowTarget.location)`，失败或 unsupported 时 fallback 到 `buildPlatformPageRoute(LocationSettingsScreen)`。
- [x] 1.2 修改 `showLocationPickerSheetOrDialog()`，通过 required callback、typedef 或等价 opener seam 打开定位设置，并移除对 `features/settings/location_settings_screen.dart` 的直接 import。
- [x] 1.3 调整 provider-not-ready prompt 的“打开设置”按钮，只负责关闭 dialog 并调用 opener，保留现有 prompt title、message、cancel 行为和 null return behavior。

## 2. Runtime Call Sites

- [x] 2.1 更新 `note_input_sheet.dart` 和 `memo_editor_screen.dart` 的定位请求调用，传入统一的 location settings opener。
- [x] 2.2 更新 `memos_list_inline_compose_coordinator.dart` 的 inline compose 定位请求调用，保持 test override/pickLocationOverride 行为不变。
- [x] 2.3 更新 `desktop_quick_input_window.dart` 的定位请求调用，保持 `desktopQuickInputCanUseLocationPicker` gate、snackbar 和 selected location behavior 不变。
- [x] 2.4 扫描 `showLocationPickerSheetOrDialog(` 的所有 runtime call sites，确认没有遗漏或重复实现 fallback `LocationSettingsScreen` route。

## 3. Focused Verification

- [x] 3.1 新增或更新 location picker focused widget test，覆盖 provider requirements 不 ready 时点击“打开设置”会调用传入 opener，并且 picker 返回 `null`。
- [x] 3.2 新增或更新架构/guardrail 测试，确保 `features/location_picker/show_location_picker.dart` 不直接 import `features/settings/location_settings_screen.dart`，也不硬编码旧 `MaterialPageRoute(LocationSettingsScreen)` 主路径。
- [x] 3.3 复用或扩展 desktop settings window focused test，确认 `DesktopSettingsWindowTarget.location` 仍进入 `Components` pane 并显示 `LocationSettingsScreen`。
- [x] 3.4 验证不会修改 `LocationSettings` model、location repository/provider/adapter、API files、WebDAV config transfer、private hooks 或 commercial/paid-feature code。

## 4. Validation

- [x] 4.1 运行 `openspec validate align-toolbar-location-settings-route --strict` 或项目当前等价 OpenSpec 校验命令。
- [x] 4.2 在 `memos_flutter_app` 运行 focused Flutter tests，至少覆盖新增 location picker test、`test/features/settings/desktop_settings_window_app_test.dart` 的 location target case，以及相关 architecture guardrail。
- [x] 4.3 在 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 4.4 如时间允许或准备 PR，运行 `flutter test`；若未运行，记录原因和剩余风险。
