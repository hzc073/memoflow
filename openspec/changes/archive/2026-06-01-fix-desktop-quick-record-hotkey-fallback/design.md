## Context

当前 `DesktopQuickInputController.registerHotKey()` 只负责注册 `DesktopShortcutAction.quickRecord` 的 `HotKeyScope.system` 热键。注册成功后，后台或隐藏到菜单栏状态可以由 system hotkey 打开桌面快速记录窗口；注册失败时只记录日志，没有把失败状态暴露给主窗口快捷键分发。

`MemosListDesktopShortcutDelegate` 目前在匹配 `quickRecord` 后只看 `traySupported()`。当 Windows tray 或 macOS status-area 可用时，它会返回 `delegated`，认为系统热键会处理该动作；这在注册失败时会产生空洞：主窗口可见并收到键盘事件，但 delegate 仍然不执行窗口内快速记录。

本 change 触及 `application/desktop` 与 `features/memos` 的既有耦合区域。当前架构阶段为 `evolve_modularity`，实现应把“系统热键是否可处理 quickRecord”保留为 application-owned runtime 状态，通过小型 seam 注入给 feature delegate，避免 feature 层继续从 tray/status-area support 推断系统热键能力。

## Goals / Non-Goals

**Goals:**
- 记录 `quickRecord` system hotkey 的最近注册结果，并能区分 registered 与 failed/unavailable。
- 在主窗口快捷键分发中，将 `quickRecord` delegated 条件从“状态栏/托盘支持”收紧为“状态栏/托盘支持且 system hotkey 已注册成功”。
- 当注册失败或不可用时，主窗口内 `quickRecord` fallback 到 `onOpenQuickRecord`，保持用户在前台窗口中的快捷键可用。
- 保持后台/隐藏到菜单栏行为的真实边界：只有 system hotkey 注册成功时才承诺后台触发。
- 用 focused tests 固化注册成功 delegated、注册失败 fallback、无状态栏支持 fallback 的差异。

**Non-Goals:**
- 不为所有桌面快捷键增加 system-wide hotkey。
- 不在设置页新增注册失败 UI、弹窗或重试按钮。
- 不承诺 App 隐藏到菜单栏且 system hotkey 注册失败时仍能响应键盘快捷键。
- 不改变用户可配置快捷键的存储格式和默认绑定。
- 不引入新的平台插件或 native Runner 改动。

## Decisions

### Decision 1: 注册状态由 `DesktopQuickInputController` 或等价 application-owned seam 拥有

`DesktopQuickInputController` 已经拥有 system hotkey 注册/注销副作用，因此它也应拥有最近一次注册状态。建议引入聚焦状态，例如 `DesktopQuickRecordHotKeyRegistrationStatus`，最少表达：

- `unavailable`：当前平台或绑定不支持注册，或尚未尝试到可用状态。
- `registered`：最近一次 system hotkey 注册成功。
- `failed`：最近一次 system hotkey 注册抛错或无法完成。

该状态可以通过只读 getter、`ValueListenable`、Riverpod provider 或 composition-root 注入 resolver 暴露给主窗口快捷键分发；具体实现应以最少改动为准，但不得让 feature delegate 直接调用 `hotKeyManager` 或自行解释插件异常。

Alternatives considered:
- 继续只看 `DesktopTrayController.supported`：拒绝。它只能说明状态栏/托盘能力存在，不能说明 system hotkey 已注册成功。
- 在 `MemosListDesktopShortcutDelegate` 里捕获注册失败：拒绝。delegate 不参与注册过程，也不应拥有插件副作用。

### Decision 2: delegate 接收“system hotkey active”语义，而不是注册细节

`MemosListDesktopShortcutDelegate` 应接收一个小型 resolver，例如 `quickRecordSystemHotKeyActive()` 或等价输入。匹配 `quickRecord` 时：

- active 为 true：返回 `delegated`，reason 保持或更新为 `handled_by_app_hotkey_manager`。
- active 为 false：调用 `onOpenQuickRecord()`，返回 `matched`，reason 使用类似 `system_hotkey_unavailable_fallback`。

这样 delegate 测试可以在不依赖 `hotkey_manager` 的情况下验证分发行为，同时避免把注册错误类型、平台插件状态泄漏到 feature 层。

Alternatives considered:
- 把 `traySupported()` 改名为 `systemHotKeySupported()` 但仍只返回状态栏能力：拒绝。命名改善不足以修复真实状态空洞。
- 在注册失败时自动关闭 tray/status-area 支持：拒绝。状态栏图标和系统热键是不同能力，不能互相覆盖。

### Decision 3: fallback 只覆盖主窗口可接收键盘事件的场景

如果 App 已隐藏到菜单栏、窗口不可见或不在当前 route，`HardwareKeyboard` handler 不会提供可靠输入源。因此注册失败时的 fallback 仅适用于 `MemosListScreen` route active、App 未锁定、窗口可见并收到按键事件的场景。

这应在 spec 与日志中保持清晰，避免把 fallback 描述成后台能力。

### Decision 4: 不新增用户打扰式提示

注册失败已经记录 error log。本 change 先不新增设置页状态提示或弹窗，避免扩大 UI/i18n 范围。若后续需要用户可见诊断，可以单独设计“桌面快捷键健康状态”能力。

## Risks / Trade-offs

- [Risk] 注册状态可能短暂滞后于偏好变更。→ Mitigation: 在每次 `registerHotKey()` 开始、成功、失败、`unregisterHotKey()` 时同步更新状态；偏好变化后现有 bootstrap 重新注册路径会刷新状态。
- [Risk] 主窗口内 fallback 可能和 system hotkey 成功路径重复触发。→ Mitigation: delegated 条件必须只在 registered 状态为 true 时成立；注册失败状态不应同时保留旧 hotkey 引用。
- [Risk] 引入状态 seam 可能加重 feature 到 application 的依赖。→ Mitigation: 通过 delegate resolver 或轻量 provider 注入布尔语义，不让 feature 层导入注册插件或访问 controller 具体实现。
- [Risk] 没有用户可见提示会让注册失败不明显。→ Mitigation: 保持 error log；本 change 聚焦行为正确性，UI 诊断另行规划。

## Migration Plan

1. 在 system hotkey 注册路径中新增并维护 `quickRecord` 注册状态。
2. 将 `MemosListDesktopShortcutDelegate` 的 quickRecord delegated 条件改为读取 `quickRecordSystemHotKeyActive` 语义。
3. 在 `MemosListScreen` 或 composition seam 中把 application-owned 注册状态接入 delegate。
4. 更新 focused tests，覆盖注册成功 delegated、注册失败 fallback、状态栏不支持 fallback 和 route inactive 不处理。
5. 运行相关快捷键与桌面 runtime tests。

Rollback 策略：若状态 seam 引发问题，可临时将 `quickRecordSystemHotKeyActive` 固定为旧 `traySupported()` 语义，但这会恢复注册失败空洞；因此 rollback 后应保留测试暴露风险。

## Open Questions

无阻塞问题。实现阶段可以在 getter、`ValueListenable` 或 provider 注入之间选择最小改动路径，只要满足 application-owned 状态与 feature delegate 只消费布尔语义这两个边界。
