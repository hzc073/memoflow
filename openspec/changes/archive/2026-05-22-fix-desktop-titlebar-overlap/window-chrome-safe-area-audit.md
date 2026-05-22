## Window Chrome Safe-Area Audit

### macOS 主窗口

- `macos/Runner/MainFlutterWindow.swift` 启用 `.fullSizeContentView`、`titlebarAppearsTransparent = true` 和 `titleVisibility = .hidden`，Flutter 内容会进入 native titlebar 区域。
- `AppleMacosPageShell` 当前只使用 `SafeArea(bottom: false)`；desktop `SafeArea` 不会为 macOS traffic lights 提供 leading inset。
- `AppleMacosPageShell` 的 navigation 位于窗口最左侧。expanded sidebar 和 rail 的 top-leading content 都可能进入 traffic-light 区域。
- `AppleMacosPageShell` 的 toolbar 在 rail 模式下从 `kWindowsDesktopRailWidth` 后开始，仍可能小于 traffic-light reserved width，需要补足剩余 leading inset。

### Settings Subwindow

- `DesktopSettingsWindowApp` 通过 `_DesktopSettingsWindowFrame` 包装内容，但 frame 只使用普通 `SafeArea` 和圆角边框。
- `_DesktopSettingsWorkbench` 自定义顶部标题栏高度为 `46`，标题左侧 padding 为 `14`，在 macOS native traffic lights 可见时会与系统窗口控件重叠。
- 设置窗口右侧关闭按钮是应用内关闭入口，应保留；macOS traffic-light 避让只影响左上 title / leading content。

### Memo Titlebar Quick Actions

- `MemosListMacosDesktopTitleBar` 已通过 `kMemosListMacosTrafficLightSafeInset = 92` 避让 traffic lights。
- 该常量目前只属于 memo widget，容易与 shell / settings window 形成重复 magic number，应迁移为共享 desktop window chrome helper。
- 现有测试 `memos_list_macos_desktop_title_bar_test.dart` 可复用为共享 helper 的回归基线。

### Coverage Gap

- 缺少 settings subwindow macOS titlebar position test。
- 缺少 `AppleMacosPageShell` 自身的 top-leading safe-area layout test。
- 缺少 helper / guardrail，防止 window chrome safe-area seam 反向依赖 feature/state/application/data。
