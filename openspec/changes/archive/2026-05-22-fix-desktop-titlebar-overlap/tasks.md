## 1. 审计与定位

- [x] 1.1 审计 macOS 主窗口、settings subwindow、memo titlebar quick actions、desktop navigation/sidebar/rail 的 top-leading chrome 布局入口，并记录哪些路径会绘制到 native titlebar 区域
- [x] 1.2 确认 macOS Runner / subwindow 的 titlebar 配置、窗口最小尺寸和现有 `SafeArea` 行为，区分主窗口与独立设置窗口的重叠来源
- [x] 1.3 检查已有 memos macOS titlebar tests，标记可复用断言与需要新增的 settings / shell coverage

## 2. Window Chrome Safe-Area Seam

- [x] 2.1 新增或整理 desktop window chrome safe-area helper / widget，集中定义 macOS traffic-light reserved inset、titlebar height 和非 macOS fallback
- [x] 2.2 确保 helper / widget 不依赖 `features/*`、`state/*`、`application/*` 或 `data/*`，并把 magic numbers 命名为可测试常量或参数
- [x] 2.3 为 helper / widget 增加 focused tests，覆盖 macOS reserved inset 与至少一个非 macOS fallback

## 3. 主窗口 Shell 修复

- [x] 3.1 将 safe-area seam 接入 `AppleMacosPageShell` 或等价 macOS shell，使 toolbar title、quick actions、navigation top-leading content 避开 native traffic lights
- [x] 3.2 检查 `DesktopShellHost`、desktop navigation sidebar/rail 与 memo titlebar quick actions，避免重复 inset、缺失 inset 或与现有 titlebar quick action layout 冲突
- [x] 3.3 补充主窗口 focused widget tests，断言 macOS top-leading titlebar / navigation content 的 global position 位于 traffic-light reserved area 之外

## 4. Settings Subwindow 修复

- [x] 4.1 将 safe-area seam 接入 `DesktopSettingsWindowApp` 的 frame 或 settings window titlebar 区域，修复“设置”标题与 macOS traffic lights 重叠
- [x] 4.2 校准 settings subwindow 在 macOS、Windows 和窄窗口下的标题、关闭按钮、sidebar、内容区域，不让 macOS inset 误伤 Windows frameless 或 mobile fallback
- [x] 4.3 增加 settings window focused widget tests，覆盖 macOS title/leading controls 不与 traffic lights 重叠，且 Windows / non-macOS 不使用 macOS leading inset

## 5. Guardrails 与验证

- [x] 5.1 增加或收紧 architecture guardrail，防止 window chrome safe-area helper 反向依赖 feature/state/application/data，满足 `evolve_modularity` touched-area improvement
- [x] 5.2 更新相关 smoke checklist 或 OpenSpec note，记录 macOS 主窗口与 settings subwindow 的窗口控件、拖拽、resize、dark mode 验收点
- [x] 5.3 运行 `flutter analyze`
- [x] 5.4 运行相关 focused widget tests 和 architecture guardrails

## 6. Login / Connect Window 补漏

- [x] 6.1 审计 `LoginScreen` 直连 `Scaffold` / `AppBar` 的 macOS titlebar 路径，确认它不经过 `DesktopShellHost` 或 settings subwindow
- [x] 6.2 将 desktop window chrome safe-area seam 接入 `LoginScreen` 的 leading titlebar 区域，修复连接页 back button / title 与 traffic lights 重叠
- [x] 6.3 增加 login macOS focused widget test，覆盖 back button 和 title 位于 traffic-light reserved area 之外
- [x] 6.4 重新运行 `flutter analyze` 与 login / window chrome focused tests
