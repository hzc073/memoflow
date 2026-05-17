## Why

首页 memo card 右上角的更多菜单目前使用默认 `PopupMenuButton` 扁平列表，视觉上和目标首页卡片风格不一致，也难以突出常用动作、更多设置和危险操作的层级关系。用户希望它改为类似参考图中的锚定浮层：上方是图标化快捷动作，中间是更多设置列表，底部单独展示删除。

## What Changes

- 将首页 memo card 右上角更多按钮的弹出样式从默认 Material popup menu 改为自定义锚定 action popover。
- 保留现有 `MemoCardAction` 行为语义和 `MemosListMemoActionDelegate` 执行动作，不新增服务器 API、数据模型或商业逻辑。
- 对 normal memo 展示两行快捷动作：复制、编辑、提醒、置顶/取消置顶、加入合集、归档。
- 对更多设置区展示修改创建时间、查看历史等次级动作，并保持可继续扩展的分组结构。
- 对删除动作使用独立危险区样式，避免和普通动作混在一起。
- 对 archived memo 保持更小的动作集合：复制、查看历史、恢复、删除，并使用同一套浮层视觉语言。
- 支持移动端点击更多按钮和 Windows 桌面右键上下文菜单共享同一套 action metadata，避免两个入口的动作顺序、标签或可见性分叉。

## Capabilities

### New Capabilities
- `home-memo-card-more-menu`: Defines the visual grouping, action availability, anchoring, and selection behavior for the home memo card more-action popover.

### Modified Capabilities
- None.

## Impact

- Affected UI: `memos_flutter_app/lib/features/memos/widgets/memos_list_memo_card.dart` and likely a new focused widget/helper under `memos_flutter_app/lib/features/memos/widgets`.
- Affected callers: `MemosListScreen` secondary-click context menu and `MemoListCard` top-right more button should continue returning `MemoCardAction` to existing handlers.
- Affected tests: update or add widget tests around menu action ordering, normal/archived visibility, grouped rendering, and action selection.
- No API contract changes and no edits expected under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api`.
- No subscription, billing, entitlement, paywall, or private-extension behavior.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 6 (feature collaboration should prefer stable seams over direct screen imports) and item 10 (touched coupled areas should be left equal or better structured). This change should extract menu presentation/action metadata out of the already large card build path rather than embedding more presentation branching directly inside `MemoListCard`.
