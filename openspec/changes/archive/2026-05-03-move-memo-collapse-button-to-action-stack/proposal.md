## Why

长篇 memo 展开后，当前“收起”入口以顶部右侧胶囊悬浮按钮出现，视觉上与列表顶部内容竞争，也和底部“回到顶部”快捷操作分散。把收起入口固定到回到顶部按钮上方，可以让长文阅读时的退出动作更稳定、更接近拇指操作区，并减少顶部悬浮遮挡感。

## What Changes

- 将展开长篇 memo 的浮动收起入口从顶部右侧胶囊按钮调整为底部右侧圆形按钮。
- 采用方案 A：收起按钮固定在 `BackToTopButton` 上方的稳定槽位；`BackToTopButton` 隐藏时，收起按钮不向下跳动。
- Match the collapse action background to `BackToTopButton` by using the theme-controlled `MemoFlowPalette.primary` color so appearance theme color changes update both controls together.
- On mobile native platforms, keep collapse and back-to-top as one vertical action group and place the group on the same screen half where the user most recently started a touch scroll; desktop platforms keep the group on the right side by default.
- 保留现有 active memo 选择、滚动可见性判断、收起行为和 haptics / accessibility 语义。
- 保留主 compose `MemoFlowFab`、底部安全区、bottom navigation / desktop layout 的既有避让关系。
- 不改变 memo 展开/收起内容策略、Markdown 渲染、API、数据模型或同步行为。

## Capabilities

### New Capabilities
- `memo-list-floating-actions`: Defines stable bottom-right floating action behavior for memo list affordances such as collapse and back-to-top.

### Modified Capabilities
- None.

## Impact

- Affected runtime code is expected to stay under `memos_flutter_app/lib/features/memos`, primarily `floating_collapse_button.dart`, `memos_list_floating_actions.dart`, `memos_list_screen_body.dart`, and nearby layout state if spacing constants need ownership.
- Affected tests are expected under `memos_flutter_app/test/features/memos`, focused on floating action rendering, visibility, ordering, and collapse wiring.
- Architecture phase is `evolve_modularity`. This change touches feature UI composition, not known `state -> features`, `application -> features`, or `core -> higher-layer` coupling hotspots. It should still keep the touched area equal or better structured by aligning memo-list floating actions behind focused widgets/tests instead of spreading layout logic across unrelated layers.
- No API route/version changes, no public/private commercial seam changes, no new dependencies.
