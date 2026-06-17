## Why

Windows 桌面首页当前把搜索作为标题栏内联展开能力：点击搜索后，搜索框会出现在顶部命令栏中间区域。这个交互挤占标题栏空间，也让右上角的预览、添加笔记、通知、设置等入口与搜索入口同时竞争注意力。

本次变更将 Windows 桌面搜索入口收敛为单一右上角搜索按钮。点击后，搜索体验在下方笔记区域切换为搜索页面视觉，复用现有显式提交搜索、快捷搜索、最近搜索和推荐标签能力。

## What Changes

- Windows 桌面右上角非窗口控制动作只保留搜索按钮。
- 点击 Windows 桌面搜索按钮后进入主笔记列表的搜索状态，而不是展开顶部命令栏搜索框。
- Windows 桌面不再使用 `MemosListDesktopSearchPresentation.header` 作为搜索承载方式。
- 搜索页继续复用现有 `draft query` / `submitted query` 语义：输入不触发查询，显式提交后才执行搜索。
- 搜索页继续展示快捷搜索、附件、链接、语音备忘、那年今日、最近搜索、推荐标签、搜索结果、loading、empty 和 error 状态。
- 不修改 API、数据库 schema、request/response model、route adapter 或 `memos_flutter_app/lib/data/api`。

## Capabilities

### Modified Capabilities

- `memo-search`: 增加 Windows 桌面搜索入口和搜索承载规则。

## Impact

- 预计影响：
  - `memos_flutter_app/lib/features/memos/memos_list_desktop_presentation.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_header_controller.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_screen.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_screen_body.dart`
  - 相关 widget/controller/view-state tests
- 不应影响：
  - macOS 和移动端搜索入口行为
  - memo search provider、search coordinator、DB search persistence
  - API compatibility tests
