## Why

当前主笔记列表的关键词搜索把 `TextEditingController.text` 直接作为 provider 查询输入，用户每输入一个字符都可能触发 `remoteSearchMemosProvider`、远端 `listMemos` 请求和本地 fallback。0611 的搜索优化已经降低了本地 2000+ 笔记场景的查询成本，但输入即搜索仍会造成多次无效请求、结果闪烁和搜索状态不清晰。

本 change 规定主笔记搜索必须区分 `draft query` 和 `submitted query`：用户输入只更新草稿，只有点击搜索按钮、键盘 Search/Enter 提交、选择历史记录或选择搜索建议后，才开始关键词搜索，并在等待结果时显示明确的搜索中页面状态。
当用户清空搜索框内容时，系统应清空 `submitted query` 并回到未搜索状态，避免继续停留在上一轮搜索结果页。

## What Changes

- 主笔记列表关键词搜索从“输入即执行”改为“显式提交后执行”。
- 搜索 UI MUST 区分：
  - `draft query`：搜索框当前文本，用户编辑时不触发 memo provider 查询。
  - `submitted query`：最近一次提交的关键词，作为 `MemosQuery.searchQuery` 和搜索高亮来源。
- 移动端搜索栏右侧当前 `取消` action 改为 `搜索` action；关闭搜索仍由左侧返回/关闭入口负责。
- 桌面标题栏搜索入口也应保持等价语义：展开搜索后，用户需要提交当前草稿才触发关键词搜索。
- 搜索框内容变化 MUST NOT 改变内容区；搜索中状态只在提交后的 keyword search loading 时出现。
- 历史记录、推荐标签、键盘 Search/Enter 仍可作为显式提交入口。
- 保持现有关键词匹配语义、远端/本地合并策略、AI 搜索显式触发策略和 0611 搜索索引优化规则不变。
- 不修改 API request/response model、route adapter、version compatibility logic 或 `memos_flutter_app/lib/data/api` 下文件。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `memo-search`：新增主笔记列表关键词搜索必须显式提交、搜索输入草稿不得触发查询、搜索中状态必须可见的行为规则。

## Impact

- 预计影响代码区域：
  - `memos_flutter_app/lib/features/memos/memos_list_header_controller.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_screen.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_screen_view_state.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_search_header.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_screen_body.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_windows_desktop_title_bar.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_macos_desktop_title_bar.dart`
  - 相关 widget/controller/view-state tests 和必要 localization 文案。
- 不应影响：
  - `memos_flutter_app/lib/data/api` 与 `memos_flutter_app/test/data/api`。
  - `MemoSearchMatcher`、`MemoSearchDocumentBuilder` 的 visible search semantics。
  - `MemoSearchDbPersistence` 的索引与 dirty backlog 优化规则。
- 架构阶段：当前为 `evolve_modularity`。本 change 主要触碰 `features/memos` UI/controller/view-state 热区，实施时应把搜索提交状态集中在 `MemosListHeaderController` 或同层 UI state seam，避免把 provider 查询决策继续散落在 widget build 中；同时不得新增 `state -> features`、`application -> features`、`core -> features` 依赖。
