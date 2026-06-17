## Why

Windows 和 macOS 桌面首页需要保持一致的搜索入口：顶部 chrome 保留排序和搜索入口，点击搜索后，搜索框出现在下方 memo 内容区域。Windows 原先会在顶部命令栏中间区域展开搜索框，macOS 也仍会把搜索框放进原生标题栏；这两个路径都会挤占标题栏空间，并让桌面端搜索体验不一致。原有排序入口需要继续保留，避免搜索入口调整回归 memo 列表排序能力。

本次变更将 Windows 和 macOS 桌面搜索入口收敛为顶部搜索按钮，并保留原有排序按钮。点击搜索后，搜索体验在下方笔记区域切换为搜索页面视觉，复用现有显式提交搜索、快捷搜索、最近搜索和推荐标签能力。

## What Changes

- Windows 和 macOS 桌面顶部 app actions 保留排序和搜索按钮。
- 点击 Windows 或 macOS 桌面搜索按钮后进入主笔记列表的搜索状态，而不是展开顶部命令栏/标题栏搜索框。
- Windows 和 macOS 桌面使用内容区搜索作为搜索承载方式。
- 搜索页继续复用现有 `draft query` / `submitted query` 语义：输入不触发查询，显式提交后才执行搜索。
- 搜索页继续展示快捷搜索、附件、链接、语音备忘、那年今日、最近搜索、推荐标签、搜索结果、loading、empty 和 error 状态。
- 不修改 API、数据库 schema、request/response model、route adapter 或 `memos_flutter_app/lib/data/api`。

## Capabilities

### Modified Capabilities

- `memo-search`: 增加 Windows/macOS 桌面搜索入口和搜索承载规则。

## Impact

- 预计影响：
  - `memos_flutter_app/lib/features/memos/memos_list_desktop_presentation.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_header_controller.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_screen.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_screen_body.dart`
  - 相关 widget/controller/view-state tests
- 不应影响：
  - 移动端搜索入口行为
  - memo search provider、search coordinator、DB search persistence
  - API compatibility tests
