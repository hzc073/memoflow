## ADDED Requirements

### Requirement: Desktop quick record SHALL fallback in the main window when system hotkey registration is unavailable
桌面快速记录 SHALL 区分 system hotkey 注册成功与状态栏/托盘能力可用这两个不同状态。当 `quickRecord` system hotkey 未注册成功时，主窗口内匹配同一快捷键的事件 SHALL 触发窗口内快速记录 fallback，而不是被标记为已委托给 system hotkey。

#### Scenario: Registered system hotkey remains delegated
- **GIVEN** 桌面平台支持状态栏或托盘能力
- **AND** `quickRecord` system hotkey 最近一次注册成功
- **WHEN** 主窗口 route active 且用户按下配置的 `quickRecord` 快捷键
- **THEN** 主窗口快捷键分发 SHALL treat the action as delegated to the system hotkey handler
- **AND** SHALL NOT 同时打开窗口内 fallback 快速记录入口

#### Scenario: Failed registration falls back in the active main window
- **GIVEN** 桌面平台支持状态栏或托盘能力
- **AND** `quickRecord` system hotkey 最近一次注册失败
- **WHEN** 主窗口 route active 且用户按下配置的 `quickRecord` 快捷键
- **THEN** 主窗口快捷键分发 SHALL invoke the in-window quick record action
- **AND** SHALL record the dispatch as matched rather than delegated

#### Scenario: Unsupported system hotkey falls back in the active main window
- **GIVEN** 当前运行环境无法提供 active `quickRecord` system hotkey handler
- **WHEN** 主窗口 route active 且用户按下配置的 `quickRecord` 快捷键
- **THEN** 主窗口快捷键分发 SHALL invoke the in-window quick record action
- **AND** 用户不需要修改快捷键绑定即可在前台窗口继续使用该动作

### Requirement: Desktop quick record SHALL preserve the background capability boundary
系统 SHALL 只在 `quickRecord` system hotkey 已注册成功时承诺后台、隐藏到菜单栏或失焦后的快速记录触发能力。注册失败 fallback SHALL 仅覆盖主窗口可接收键盘事件的场景，不得被描述或实现为后台热键能力。

#### Scenario: Hidden app requires registered system hotkey
- **GIVEN** App 已隐藏到菜单栏或后台且主窗口无法接收 `HardwareKeyboard` 事件
- **AND** `quickRecord` system hotkey 未注册成功
- **WHEN** 用户按下配置的 `quickRecord` 快捷键
- **THEN** 系统 SHALL NOT claim that in-window fallback can handle the event
- **AND** 行为说明、日志或测试 SHALL 保持 system hotkey 注册成功是后台触发的前提

#### Scenario: Foreground route guard still applies
- **GIVEN** 主窗口 route inactive 或应用锁处于 locked 状态
- **WHEN** 用户按下配置的 `quickRecord` 快捷键
- **THEN** 主窗口快捷键分发 SHALL NOT open in-window quick record via fallback
- **AND** SHALL preserve existing route/lock guards

### Requirement: Desktop quick record hotkey registration state SHALL be owned outside feature UI
`quickRecord` system hotkey 注册状态 SHALL 由 `DesktopQuickInputController` 或等价 application-owned desktop runtime seam 维护。Feature UI 和快捷键 delegate SHALL 只消费“system hotkey 是否 active”的语义输入，不得直接调用 `hotKeyManager`、解析插件异常或用 tray/status-area support 代替注册结果。

#### Scenario: Registration success updates active state
- **WHEN** `quickRecord` system hotkey 注册成功
- **THEN** application-owned runtime seam SHALL expose the system hotkey as active
- **AND** subsequent main-window `quickRecord` dispatch MAY be delegated

#### Scenario: Registration failure updates inactive state
- **WHEN** `quickRecord` system hotkey 注册失败、被注销或当前平台不可用
- **THEN** application-owned runtime seam SHALL expose the system hotkey as inactive
- **AND** feature-level shortcut dispatch SHALL be able to choose in-window fallback without importing hotkey plugin code

#### Scenario: Preference change refreshes registration state
- **WHEN** 用户修改 desktop shortcut bindings and the bootstrap path re-registers `quickRecord`
- **THEN** 注册状态 SHALL reflect the latest attempted binding
- **AND** stale success state SHALL NOT keep main-window dispatch delegated after a later registration failure
