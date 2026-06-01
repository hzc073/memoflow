## 1. 偏好模型与状态

- [x] 1.1 在 `DevicePreferences` 中新增 `macosCloseToMenuBar`，默认值为 `true`，并补齐 `toJson`、`fromJson`、`fromLegacy`、`copyWith` 与 equality 覆盖
- [x] 1.2 在 `DevicePreferencesController` 中新增 `setMacosCloseToMenuBar`，确保写入路径仍由 `state/settings` 拥有且不新增 `features/*` import
- [x] 1.3 补充或更新 device preferences serialization/provider 测试，覆盖缺失字段默认 true、显式 false 可持久化、Windows `windowsCloseToTray` 不受影响

## 2. macOS close lifecycle

- [x] 2.1 扩展 `DesktopExitCoordinator` 的纯 close policy/debug helper，将 macOS preference、status icon support、secondary route state 纳入可测试决策
- [x] 2.2 更新 macOS `_requestClose`：secondary route first；`macosCloseToMenuBar == true` 且 status icon supported 时隐藏到菜单栏；disabled 时保留既有 native/full-exit close path
- [x] 2.3 在 `DesktopTrayController` 中补充中性或 macOS 语义的 hide/show wrapper，复用现有 tray/menu-bar 初始化与 restore 行为，避免 macOS 调用 Windows 命名偏好的业务判断
- [x] 2.4 验证 `Cmd+Q`、application menu Quit、菜单栏状态图标退出不会被 close-to-menu-bar 误拦截；如发现 native Quit 被 `setPreventClose(true)` 当作普通 close，则增加最小 termination-intent seam

## 3. 桌面设置 UI

- [x] 3.1 在 `DesktopSettingsScreen` 中新增 macOS 专属 section/toggle row，仅在 `PlatformTarget.macOS` 显示，并继续使用 `SettingsSection` / `SettingsToggleRow`
- [x] 3.2 保持 Windows section 只控制 `windowsCloseToTray`，不重命名、不复用为 macOS 设置
- [x] 3.3 补充 macOS close-to-menu-bar label/description 的 i18n 文案，并按项目现有流程同步 generated localization 文件

## 4. 测试与边界保护

- [x] 4.1 更新 `desktop_exit_coordinator_test.dart`，覆盖 macOS enabled hide-to-menu-bar、disabled native/full-exit、secondary route first、Windows close-to-tray 无回归
- [x] 4.2 增加 Desktop settings widget/platform tests，覆盖 macOS row 只在 macOS 显示、Windows row 只在 Windows 显示、非桌面平台不显示平台专属 row
- [x] 4.3 增加或调整 architecture/guardrail 检查，防止 macOS user-facing close path 绕过 approved lifecycle coordinator，并确认未新增 `application -> features`、`state -> features`、`core -> higher layer` 依赖
- [x] 4.4 检查公共仓库边界，确认本 change 未引入 subscription、billing、entitlement、StoreKit、paywall、private overlay 或 `AccessDecision.source` business branching

## 5. 验证

- [x] 5.1 在 `memos_flutter_app` 运行 focused tests：desktop lifecycle、device preferences、desktop settings widget/guardrail tests
- [x] 5.2 在 `memos_flutter_app` 运行 `flutter analyze`
- [ ] 5.3 在 macOS 手动 smoke：关闭主窗口后进程与菜单栏图标保留、Dock 中无最小化窗口项、菜单栏恢复主窗口、`Cmd+Q` 和退出菜单真正退出
