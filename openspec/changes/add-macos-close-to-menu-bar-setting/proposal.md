## Why

macOS 用户通常期望工具型应用在关闭主窗口后仍留在菜单栏，方便从右上角状态图标恢复；当前 macOS 路径会关闭窗口并由 Runner 在最后一个窗口关闭后退出应用。这个行为与已经存在的 macOS 菜单栏图标能力不一致，也让“关闭窗口”和“退出应用”的语义不够清晰。

## What Changes

- 增加 macOS 专属桌面设置，默认开启，用于控制关闭主窗口时是否保持应用在菜单栏运行。
- 当该设置开启时，macOS 主窗口关闭请求 SHALL 隐藏主窗口并保留菜单栏图标，进程不得退出。
- 菜单栏图标及其菜单 SHALL 能恢复主窗口；恢复后窗口应显示并获得焦点。
- `Cmd+Q`、macOS application menu 的 Quit、以及菜单栏图标菜单中的退出命令 SHALL 继续表示真正退出应用。
- 不复用 `windowsCloseToTray`；新增 macOS 专属偏好或等价的中性 lifecycle seam，避免 Windows 命名污染 macOS 行为。
- 通过 `DesktopExitCoordinator` / `DesktopTrayController` 等 application-owned desktop lifecycle seam 承载窗口副作用，设置 UI 仅表达偏好意图。
- 当前架构阶段为 `evolve_modularity`。本 change 会触及 `application/desktop`、`state/settings`、`features/settings` 和 macOS Runner；实现 SHALL 不新增 `application -> features`、`state -> features`、`core -> higher layer` 依赖，并通过扩展纯 lifecycle policy / focused tests 让 touched desktop lifecycle area 至少保持同等或更好结构。

## Capabilities

### New Capabilities
- `macos-close-to-menu-bar-lifecycle`: 定义 macOS 主窗口关闭到菜单栏、菜单栏恢复、默认开启设置、以及真正退出路径的 lifecycle 语义。

### Modified Capabilities
- `desktop-kernel-behavior`: 明确 macOS 主窗口关闭副作用也必须进入 shared desktop close coordinator 或等价 application-owned lifecycle seam，不能由页面或 shell 直接绕过。
- `platform-adaptive-ui-system`: 明确桌面设置页可以按当前平台显示 macOS 专属 lifecycle 设置，并继续使用 settings semantic components。
- `macos-app-menu`: 明确在 macOS close-to-menu-bar 开启时，application menu 的 Quit / `Cmd+Q` 仍然是完整退出，不得退化为隐藏窗口。

## Impact

- Flutter/Dart：`memos_flutter_app/lib/application/desktop/desktop_exit_coordinator.dart`、`memos_flutter_app/lib/application/desktop/desktop_tray_controller.dart`、`memos_flutter_app/lib/data/models/device_preferences.dart`、`memos_flutter_app/lib/state/settings/device_preferences_provider.dart`、`memos_flutter_app/lib/features/settings/desktop_settings_screen.dart`、相关 i18n 文案与 focused tests。
- Native macOS：`memos_flutter_app/macos/Runner/AppDelegate.swift` 需要验证或调整 native close/terminate 边界，确保 close-to-menu-bar 路径不会被当作最后窗口关闭退出，同时保留 Quit 的标准退出语义。
- Tests/guardrails：更新 desktop lifecycle unit tests，补充 macOS close-to-menu-bar 决策覆盖；必要时增加 native source guardrail，防止 `applicationShouldTerminateAfterLastWindowClosed` 回退为自动退出。
- Public/private boundary：本 change 仅涉及公共桌面 lifecycle 与设置，不得引入 subscription、billing、entitlement、StoreKit、paywall、private overlay 或 `AccessDecision.source` business branching。
