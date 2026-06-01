## Context

当前 macOS desktop runtime 已经具备菜单栏状态图标基础能力：`DesktopTrayController.supported` 覆盖 Windows 和 macOS，`main.dart` 在 supported desktop tray runtime 中会初始化图标，macOS 图标使用 `assets/images/tray_icon_macos.png` 和 template rendering。

当前 close lifecycle 的分流仍偏 Windows：`DesktopExitCoordinator.attachWindowListener()` 已在 Windows/macOS 设置 `windowManager.setPreventClose(true)`，但 `_requestClose()` 在 macOS 只处理 secondary route，然后关闭 native window。由于 `AppDelegate.applicationShouldTerminateAfterLastWindowClosed` 当前返回 `true`，这会使“关闭主窗口”接近“退出应用”。

设置层当前只有 `windowsCloseToTray`，`DesktopSettingsScreen` 也只有 Windows 专属 close-to-tray row。macOS 需要独立偏好，不能复用 Windows 字段或文案。

架构阶段为 `evolve_modularity`，本 change 触及 `application/desktop`、`state/settings`、`features/settings`、macOS Runner 和 tests。实现后依赖方向 SHALL 保持：

- `features/settings` 可以读取/更新 settings state，但只表达 UI 和用户意图。
- `state/settings` 继续拥有 `DevicePreferences` 读写，不新增 `features/*` import。
- `application/desktop` 继续拥有窗口 lifecycle 副作用，不新增 `features/*` import。
- macOS Runner 只处理 native lifecycle/menu glue，不引入商业/private 逻辑。

## Goals / Non-Goals

**Goals:**
- 在 macOS 上新增默认开启的 close-to-menu-bar 偏好。
- 开启时，关闭主窗口隐藏窗口并保留菜单栏状态图标和进程。
- 关闭后不产生 Dock 中的最小化窗口项，用户可从菜单栏图标恢复。
- `Cmd+Q`、application menu Quit 和菜单栏状态图标退出仍然是真正退出。
- 将 macOS close policy 提取为可测试的 application-owned lifecycle 决策，减少 platform close 逻辑散落。
- 桌面设置页使用现有 settings semantic components，并只显示当前平台专属 lifecycle row。

**Non-Goals:**
- 不改变 Windows `windowsCloseToTray` 默认值、存储 key 或行为。
- 不重做 macOS menu structure，不迁移新的菜单命令到 settings window。
- 不实现 launch-at-login、全局后台服务、通知中心常驻或隐藏 Dock app icon 的 activation policy。
- 不新增商业、订阅、StoreKit、entitlement、paywall 或 private overlay 逻辑。

## Decisions

### Decision 1: 新增 `macosCloseToMenuBar`，不复用 `windowsCloseToTray`

`DevicePreferences` 增加 macOS 专属布尔字段，建议命名为 `macosCloseToMenuBar`，默认值为 `true`。`fromJson` 对缺失字段使用默认值，`toJson` 写入独立 key，`DevicePreferencesController` 增加 `setMacosCloseToMenuBar`。

Alternatives considered:
- 复用 `windowsCloseToTray`：拒绝。字段名、UI 文案和用户心智都绑定 Windows tray，复用会让 macOS 行为被 Windows 设置污染。
- 改成完全中性字段如 `desktopCloseToStatusArea`：暂不采用。Windows 既有 key 已存在，强行迁移会扩大兼容风险；新增 macOS key 更小。

### Decision 2: 开启时 hide 主窗口，而不是真正 close native window

macOS close-to-menu-bar enabled 时，`DesktopExitCoordinator` SHALL 保持 close prevention，并调用 `DesktopTrayController` 的 macOS status-area hide path 隐藏主窗口。这样主 Flutter window 和 Dart isolate 仍存在，菜单栏图标、provider state 和 restore path 都保持稳定。

`AppDelegate.applicationShouldTerminateAfterLastWindowClosed` 不作为主要实现机制。实现阶段需要验证 native Quit 与 last-window close 边界；只有当测试/实机验证显示必须调整时，才对 `AppDelegate.swift` 做最小改动。

Alternatives considered:
- 将 `applicationShouldTerminateAfterLastWindowClosed` 改为 `false` 并真正 close 主窗口：风险较高。主 Flutter window 被销毁后恢复窗口、保持 Dart 状态和菜单栏 callback 都更复杂。
- 最小化到 Dock：拒绝。用户目标是关闭窗口后继续留在菜单栏，不是在 Dock 保留一个最小化窗口项。

### Decision 3: Close 和 Quit 分流必须显式

用户 close 主窗口时走 close policy：secondary route first，然后根据 macOS preference 和 status icon support 决定 hide-to-menu-bar 或既有 native/full-exit path。

显式退出走 exit policy：application menu Quit / `Cmd+Q` SHALL 继续终止进程；菜单栏状态图标的退出命令 SHOULD 进入 `DesktopExitCoordinator.requestExit(reason: 'tray_exit')`，完成可用 cleanup 后再终止。若 `setPreventClose(true)` 导致 native Quit 被当作普通 close，需要增加最小 native/Dart termination-intent seam，使 Quit 绕过 hide-to-menu-bar。

Alternatives considered:
- 让所有 macOS close/quit 都走同一个 `windowManager.close()`：拒绝。它无法表达“close 隐藏，Quit 退出”的差异。
- 在 settings UI 中直接调用 window APIs：拒绝。窗口副作用必须留在 application desktop lifecycle seam。

### Decision 4: 为 close policy 增加可测试的 macOS 输入

现有 `debugCloseRequestAction` 只覆盖 Windows close-to-tray split，`debugMacosCloseRequestAction` 只覆盖 secondary route vs native close。实现应把 macOS preference、status icon support 和 secondary route state 纳入纯决策 helper，返回明确 action，例如 `popSecondaryRoute`、`hideToMenuBar`、`nativeClose` 或 `fullExit`。

这也是本 change 的 modularity improvement：把新增平台 lifecycle 差异集中在 application-owned policy/test seam，避免 feature page 或 settings row 自己判断窗口副作用。

### Decision 5: 设置页按当前平台显示专属 sections

`DesktopSettingsScreen` 继续使用 `SettingsPage`、`SettingsSection`、`SettingsToggleRow`。macOS section 只在 `PlatformTarget.macOS` 显示，Windows section 只在 `PlatformTarget.windows` 显示；共享 Desktop section 保留快捷键入口。

文案应走现有 i18n 管线；如果现有 generated strings 需要更新，任务中应包含生成或同步步骤。实现不得用 settings row 文案暗示 Windows tray 是 macOS 菜单栏。

## Risks / Trade-offs

- [Risk] `setPreventClose(true)` 可能影响 `Cmd+Q` / native Quit，使 Quit 也触发普通 close callback。→ Mitigation: 实现阶段必须在 macOS 上验证 Quit；如有冲突，增加 native termination-intent seam，并补测试/guardrail。
- [Risk] hide 主窗口会保留 Flutter window 和运行时资源。→ Mitigation: 这是为了稳定恢复和菜单栏 callback 的有意取舍；explicit Quit 仍负责释放资源。
- [Risk] 菜单栏图标初始化或资源路径在 macOS 打包中失效。→ Mitigation: 复用现有 `DesktopTrayController.ensureInitialized()` 和 `tray_icon_macos.png`，补 focused test 或手动验证项。
- [Risk] 新 preference 字段与旧本地数据兼容。→ Mitigation: 缺失字段默认 true，无需迁移文件；serialization tests 覆盖默认解析。
- [Risk] 桌面设置页再次出现平台分支扩散。→ Mitigation: 分支只保留在 top-level platform section selection；row rendering 继续走 settings semantic seam。

## Migration Plan

1. 扩展 `DevicePreferences` 与 provider setter，缺失 `macosCloseToMenuBar` 时默认 true。
2. 扩展 `DesktopExitCoordinator` macOS close policy：secondary route first，enabled 时 hide-to-menu-bar，disabled 时保留既有 native/full-exit close path。
3. 复用或补充 `DesktopTrayController` 的中性/macOS hide/show 方法，确保菜单栏图标 restore path 可用。
4. 在 `DesktopSettingsScreen` 增加 macOS section 和 toggle row，补充 i18n 文案。
5. 验证 `Cmd+Q`、application menu Quit、菜单栏状态图标退出；必要时对 `AppDelegate.swift` 增加最小 termination-intent 支持。
6. 更新 focused tests 与 guardrails。

Rollback 策略：保留新增 preference 字段无害；若 macOS close-to-menu-bar 行为需要回滚，可让 macOS policy 回到 native close path，并隐藏 macOS setting row。Windows behavior 不应受影响。

## Open Questions

- 无阻塞问题。实现阶段唯一需要实机确认的是 macOS `setPreventClose(true)` 与 `Cmd+Q` / application menu Quit 的交互；若发现 Quit 被拦截，需要按 Decision 3 增加最小 native/Dart termination-intent seam。
