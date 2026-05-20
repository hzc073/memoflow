## Why

macOS 主页当前仍缺少更像 Apple 桌面应用的顶部窗口体验。Windows 端已经能把三个快捷入口胶囊放进自绘标题栏，但 macOS 直接照搬 Windows frameless / 右侧窗口控制按钮会破坏 Apple 平台用户对 traffic lights、`Cmd+W`、Window menu、全屏和系统窗口状态的预期。

用户希望后续把主页的三个快捷按钮胶囊移动到标题栏区域，以释放页面首屏空间并让快捷入口始终处于高可见位置。这个目标可以通过 macOS hybrid titlebar 实现：保留系统窗口控制按钮，让 Flutter 内容延伸到标题栏区域并承载现有 `MemosListPillRow`，而不是全量自绘 macOS 窗口 chrome。

当前架构阶段为 `evolve_modularity`，基线 modularity score 为 `4/10`。本变更会触及 `features/memos`、desktop shell / window chrome、macOS Runner 或平台窗口 seam 等耦合热点，因此必须让触达区域保持 equal or better structured，避免新增 `core -> features`、`application -> features` 或 scattered platform branches。

## What Changes

- 为 macOS 主页引入 hybrid titlebar 目标：保留原生 traffic-light window controls，允许 Flutter 内容扩展进标题栏区域。
- 将主页三个快捷入口胶囊从内容 header 区迁移到 macOS 标题栏中心/可用区域，并继续复用 `MemosListPillRow` / `HomeQuickActionChipData` 等现有状态与组件。
- macOS 标题栏布局必须避让左上角 traffic lights，并保留可拖动空白区域；交互控件区域不能被 `DragToMoveArea` 吃掉点击。
- 不照搬 Windows 的右侧 minimize / maximize / close 自绘按钮，不让 macOS 主窗口变成全 frameless Windows-style chrome。
- 如果需要 Runner 层支持，应集中在 macOS window chrome seam 中设置 `fullSizeContentView`、transparent titlebar 或等价原生窗口属性。
- 增加 focused widget / guardrail 覆盖，防止 macOS titlebar 引入 Windows window controls 或商业化逻辑。

## Capabilities

### Modified Capabilities

- `apple-platform-ui-adaptation`: 明确 macOS home titlebar 可以使用 hybrid native/system window chrome，让 Flutter 承载标题栏内容，同时保留 Apple 系统窗口语义。

## Impact

- 预计受影响代码主要在 `memos_flutter_app`：
  - `lib/features/memos/widgets/memos_list_screen_body.dart`
  - `lib/features/memos/widgets/memos_list_windows_desktop_title_bar.dart` 或后续抽出的 shared desktop titlebar / macOS titlebar widget
  - `lib/features/memos/widgets/memos_list_search_widgets.dart`
  - `lib/features/memos/home_quick_actions.dart`
  - `macos/Runner/MainFlutterWindow.swift` 或新增 macOS window chrome seam
  - 相关 widget tests / architecture guardrails
- 不触碰 API 请求/响应、route adapters、version compatibility logic 或 `memos_flutter_app/lib/data/api`。
- 不新增 StoreKit、subscription、entitlement、receipt、paywall、price、product ID 或其他商业化逻辑。

## Non-Goals

- 不重做完整 macOS 主页导航系统。
- 不把 macOS 主窗口改成完全 frameless 的 Windows-style shell。
- 不自绘 macOS traffic lights。
- 不迁移设置窗口行为；设置窗口的 hybrid titlebar 可作为后续独立 change。
- 不改变三个快捷入口的业务含义、可配置来源或数据模型。
