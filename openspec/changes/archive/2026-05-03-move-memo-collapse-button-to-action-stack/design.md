## Context

当前 memo list 有两类右侧浮动操作：

- `MemoFloatingCollapseButton`：当长篇 memo 展开且卡片内联 `Collapse` toggle 离开当前 viewport 足够远时显示；当前视觉为顶部右侧胶囊按钮。
- `BackToTopButton`：当列表滚动到一定位置后显示；当前视觉为底部右侧圆形按钮，并通过 `backToTopBaseOffset + bottomInset` 避开 compose FAB、bottom safe area 和 bottom navigation。

用户选择方案 A：把长篇 memo 的浮动收起按钮做成圆形按钮，固定在 `BackToTopButton` 上方；`BackToTopButton` 隐藏时不压缩槽位，避免收起按钮上下跳动。

现有 active memo 解析由 `MemosListFloatingCollapseController` 负责，卡片通过 `MemoFloatingCollapseGeometry` 上报 card/toggle offset。这个选择逻辑已经满足“只在需要远程收起入口时显示”的要求，本变更不需要重写。

Architecture phase is `evolve_modularity`. 本变更预计只触碰 `features/memos` UI composition，不涉及已知 `state -> features`、`application -> features`、`core -> higher-layer` dependency hotspots。依赖方向 before/after 应保持为 feature widget 内部组合，不新增跨层 import。

## Goals / Non-Goals

**Goals:**

- 将浮动收起入口从顶部右侧胶囊按钮改为底部右侧圆形按钮。
- 让收起按钮固定在回到顶部按钮上方的稳定槽位，采用方案 A 的 non-jumping behavior。
- 保留 `MemosListFloatingCollapseController` 的 active memo 选择、滚动中 opacity 行为、点击收起目标 memo 的行为。
- 保留 `BackToTopButton` 的显示时机、点击行为、haptics、bottom inset / compose FAB 避让。
- 增加 focused widget tests，防止按钮位置、可见性和 collapse wiring 回退。

**Non-Goals:**

- 不改变长篇 memo 的 truncation threshold、collapsed preview line count 或 Markdown rendering。
- 不改变 memo 数据模型、repository、sync、API 或 server compatibility。
- 不重构 home navigation、bottom navigation、desktop preview pane 或 compose FAB。
- 不引入 private/commercial capability branching。

## Decisions

### Decision 1: Reuse the existing collapse controller

保留 `MemosListFloatingCollapseController` 和 `MemoFloatingCollapseGeometry`。卡片仍然上报内联 toggle 的位置，controller 仍然决定是否需要外部 collapse affordance。

Alternative considered: 只要 memo 展开就显示底部收起按钮。这个方案更简单，但会在内联 `Collapse` 按钮仍可见时产生重复入口，违背当前“只有内联入口远离 viewport 时才显示”的语义。

### Decision 2: Use a stable bottom-right action stack

在 `MemosListScreenBody` 的 `Stack` 中用底部右侧固定槽位组合 `MemoFloatingCollapseButton` 和 `BackToTopButton`：

```text
right edge
   │
   ├─ [collapse circle]  ← stable slot
   │        gap
   └─ [back-to-top circle] ← existing slot, may fade out
```

`BackToTopButton` 隐藏时仍然保留 collapse button 的相对位置。这样长文阅读时“收起”按钮不会因为滚动状态或回到顶部按钮显隐而上下跳动。

Alternative considered: Dynamic stack where collapse moves down when back-to-top is hidden. 这会更靠近底部，但在滚动阈值附近会产生 vertical jump，不符合“固定按钮”的体验目标。

### Decision 3: Convert collapse visual to circular icon affordance

`MemoFloatingCollapseButton` 应从 text pill 转为圆形 icon button，尺寸和 visual weight 与 `BackToTopButton` 接近。它继续使用 `msg_collapse` 作为 `Semantics` / tooltip label，避免纯图标降低可访问性。

The collapse action background SHALL use the same theme-controlled `MemoFlowPalette.primary` source as `BackToTopButton`, with a white icon and matching circular shadow treatment. This keeps both controls visually part of the same floating action family and ensures Appearance theme color changes update both controls together.

图标应与 `BackToTopButton` 的 `keyboard_arrow_up` 区分，优先选择表达“收起/压缩”的 icon（例如 `unfold_less_rounded` 或等价语义图标），避免两个相邻按钮都像“向上滚动”。

Alternative considered: 继续显示“Collapse”文字。文字清晰但占用横向空间，也会破坏底部动作区的一致圆形视觉。

### Decision 4: Keep spacing ownership local to memo list floating actions

实现时优先把 size/gap/offset constants 收敛在 memo list floating action widgets 或 `MemosListScreenBody` 的局部私有常量中，不把 UI-only spacing 推入 lower layers。这样可保持 dependency direction unchanged，并让 touched area equal or better structured。

### Decision 5: Mobile action group follows the touch-scroll side

The collapse and back-to-top controls remain one vertical action group. On mobile native platforms (`TargetPlatform.android` and `TargetPlatform.iOS`), the group side is derived from the most recent touch scroll start position:

```text
screen width / 2
      │
left  │  right
      │
[actions]       or       [actions]
```

The side change should be committed from a real scroll/drag start, not from a plain tap. This avoids moving the buttons when a user simply taps content or a memo card. A practical implementation can inspect `ScrollStartNotification.dragDetails.globalPosition`, convert it into the memo list body coordinate space, and compare `localDx` with `bodyWidth / 2`.

Desktop and non-mobile platforms keep the action group on the right side. This preserves stable mouse/trackpad/keyboard behavior because desktop scrolling does not reliably communicate a left-hand/right-hand operation intent.

Alternative considered: update the side from every pointer down. That would feel more responsive but would also move the action group after ordinary taps, long presses, or context-menu gestures. Scroll-start based detection better matches the stated “滑动浏览” intent.

## Risks / Trade-offs

- [Risk] `BackToTopButton` 隐藏时 collapse button 下方会留出一个按钮槽位的空白 → Mitigation: 这是方案 A 的预期 trade-off，换取稳定位置；测试应覆盖隐藏 back-to-top 时 collapse 不下移。
- [Risk] 两个圆形按钮图标相似导致语义混淆 → Mitigation: 使用不同 icon，并保留 tooltip / semantics label。
- [Risk] 底部动作栈可能与 compose FAB、bottom navigation 或 safe area 重叠 → Mitigation: 复用现有 `backToTopBaseOffset + bottomInset` 作为 bottom anchor，再按 button size + gap 向上布局。
- [Risk] Full-screen overlay hit testing 影响列表交互 → Mitigation: 用窄 `Positioned` action stack 或确保 hidden/transparent actions ignore pointer，不保留不必要的 full-screen interactive layer。
- [Risk] Desktop wide layout 和 mobile bottom navigation 布局差异造成位置偏差 → Mitigation: focused tests 使用 body-level listenables 覆盖 visibility/order，screen-level tests 保留 collapse wiring。
- [Risk] Mobile action group may switch sides too eagerly around the exact center line → Mitigation: switch only on scroll start; at the exact midpoint, preserve the current side rather than toggling.
- [Risk] Desktop pointer signals could be mistaken as side intent → Mitigation: adaptive side logic is mobile-only; desktop always resolves to the right side.

## Migration Plan

1. 更新 memo list floating action UI 和 body overlay composition。
2. 更新或新增 widget tests 覆盖方案 A 的稳定槽位、圆形按钮、隐藏 back-to-top 时的行为和 collapse callback。
3. 运行 focused tests，再运行 `flutter analyze` 和 `flutter test`。

Rollback strategy: 恢复 `MemoFloatingCollapseButton` 的顶部右侧 pill overlay composition；controller 和 card geometry 不需要迁移。

## Open Questions

- 最终 icon 选择：优先 `Icons.unfold_less_rounded`，但实现时可根据实际视觉与 `BackToTopButton` 做微调。
- 按钮尺寸是否完全复用 `BackToTopButton` 的 `44x44`，或使用略小尺寸；默认应先复用以保持动作栈一致。
