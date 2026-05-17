## Context

首页 memo card 的更多动作现在分散在 `memos_list_memo_card.dart` 内部：`MemoCardAction` 定义动作枚举，`buildMemoCardActionMenuItems` 生成默认 `PopupMenuEntry`，`showMemoCardContextMenu` 给 Windows 右键调用，卡片右上角则直接使用 `PopupMenuButton`。真正执行业务动作的是 `MemosListMemoActionDelegate.handleMemoAction`，因此这次变更应只替换菜单呈现层，不改变动作语义。

该区域同时被 `show-home-memo-engagement` 变更触达，但两个 change 的职责不同：engagement 负责点赞/评论显示与操作，本 change 只负责 memo card 右上角更多菜单的弹出样式、分组和入口复用。

## Goals / Non-Goals

**Goals:**
- 将首页 memo card 更多菜单改为参考图风格的锚定浮层。
- 让 normal memo 的常用动作以 icon + label tile 形式分组展示。
- 让修改创建时间、查看历史等次级动作位于独立的更多设置区。
- 让删除动作使用独立 danger section。
- 让卡片右上角更多按钮和 Windows secondary-click context menu 共享同一套 action metadata。
- 保留现有 `MemoCardAction`、`MemosListMemoActionDelegate`、确认删除、归档、恢复、提醒、合集等行为。
- 在 `evolve_modularity` 下把菜单 presentation/model 从已经很大的 card build path 中拆出，避免继续加重 `MemoListCard`。

**Non-Goals:**
- 不新增 memo action。
- 不改变 action 执行顺序之外的业务语义。
- 不改变 Memos server API、request/response model 或 API compatibility tests。
- 不重做首页 card 整体布局、engagement 显示、编辑器、提醒编辑页或合集选择页。
- 不引入 subscription、billing、entitlement、paywall 或 private/commercial branching logic。

## Decisions

1. 新增共享 action metadata seam，而不是继续只返回 `PopupMenuEntry`。

   建议引入类似 `MemoCardActionMenuModel` / `MemoCardActionDescriptor` 的轻量结构，描述 action、label、icon、group、danger state、availability。`MemoListCard` 顶部按钮和 `showMemoCardContextMenu` 都从同一个 model 生成 UI。

   Alternative considered: 在 `PopupMenuButton.itemBuilder` 里继续堆更复杂的 `PopupMenuItem`。这会让默认 popup menu 继续限制布局，也会让右键菜单和按钮菜单更容易分叉。

2. 使用自定义 `showMemoCardActionPopover` 浮层，而不是默认 `PopupMenuButton`。

   该浮层可以用 `showGeneralDialog` 或局部 `OverlayEntry` 实现，关键是接收 anchor rect 或 global position，并在 viewport 内 clamp。`showGeneralDialog` 更容易得到 barrier dismiss、动画和 widget test 稳定性；`OverlayEntry` 更轻，但生命周期和 dismiss 管理更容易变散。实现时可以优先选择一个小而可测试的 helper。

   Alternative considered: 使用 `showModalBottomSheet`。它实现简单，但丢失参考图中的 card-local anchored feel，也不适合作为 Windows 右键菜单。

3. 菜单视觉分为三层。

   Normal memo:

   ```text
   primary grid
   ┌──────┬──────┬──────┐
   │ copy │ edit │ bell │
   ├──────┼──────┼──────┤
   │ pin  │ add  │ arch │
   └──────┴──────┴──────┘

   secondary list
   - change created time >
   - history             >

   danger row
   - delete
   ```

   Archived memo 使用同一视觉容器，但动作集合收缩为 copy、history、restore、delete。若 primary grid 不足六项，允许使用较小网格或 list fallback，但 danger row 仍独立。

   Alternative considered: 所有动作都做成 grid。这样视觉统一，但修改时间、历史这类“更多设置”动作会和常用动作抢层级，和参考图不一致。

4. 保持动作选择协议不变。

   浮层只返回 `MemoCardAction`。调用方继续执行 `onAction(action)` 或 `_memoActionDelegate.handleMemoAction(memo, action)`。删除确认、归档后的移除动画、恢复 toast、提醒编辑、加入合集等流程继续由现有 delegate/callers 负责。

   Alternative considered: 让 popover 直接执行操作。这样会把业务流程塞进 widget，违反本 change 的 scoped UI 目标，也会增加 `features/memos/widgets` 对 screen state 的耦合。

5. 优先复用现有本地化文案。

   动作标签继续使用现有 `strings.legacy`、`memoTimeAdjustment.action`、`settings.preferences.history`、`collections.addToCollection` 等文案。更多设置标题优先复用已有 localized `moreSettingsTitle` 文案，避免为了一个标题引入新的 localization churn；若实现时发现没有合适入口，再把 localization 变更作为明确任务补充。

## Risks / Trade-offs

- [Risk] 自定义浮层可能在小屏、横屏或接近屏幕边缘时溢出。→ Mitigation: position helper 必须根据 overlay size、safe area 和目标宽高 clamp，并用 widget tests 覆盖边缘 anchor。
- [Risk] 顶部按钮菜单和 Windows 右键菜单动作不一致。→ Mitigation: 两个入口共享同一 action metadata builder，测试直接断言 normal/archived action order。
- [Risk] 与 `show-home-memo-engagement` 同时修改 `memos_list_memo_card.dart` 出现合并冲突。→ Mitigation: 尽量把新 popover 和 menu model 放到独立文件，`MemoListCard` 只保留最小接入点。
- [Risk] 视觉还原过度依赖固定尺寸，导致长文案或多语言溢出。→ Mitigation: 使用有约束的 tile 尺寸、`maxLines`/ellipsis、最小 touch target，并在窄宽下允许布局收缩或换行。
- [Risk] 替换默认 `PopupMenuButton` 后丢失键盘/无障碍 dismiss。→ Mitigation: 保留 trigger tooltip/semantic label，浮层支持 barrier dismiss 和 Escape/back dismiss，action tile 同时有 icon 和 text label。

## Migration Plan

1. 提取 `MemoCardAction` metadata builder，覆盖 normal/archived 两种状态。
2. 新增 focused popover surface/helper，并实现 anchor positioning、viewport clamp、dismiss 和 action selection。
3. 替换 `MemoListCard` 右上角 `PopupMenuButton` 接入点。
4. 替换 `showMemoCardContextMenu` 的默认 `showMenu` 接入点，让 Windows secondary-click 复用同一浮层。
5. 更新测试：action order、normal/archived visibility、分组渲染、选择 action、边缘定位。

Rollback path: 如果自定义浮层出现无法快速修复的交互回归，可以恢复 `PopupMenuButton` 和 `showMenu` 调用，同时保留 action metadata builder 作为后续再接入的准备。

## Open Questions

- 图标集是否使用现有 Material `Icons` 即可，还是希望明确改用 `phosphor_flutter` 的线性图标来更贴近参考图？
- Archived memo 是使用紧凑 grid 还是 list fallback 更符合你预期？
- 是否需要为 popover 增加轻微背景 blur，还是只使用白色/深色 surface + shadow 即可？
