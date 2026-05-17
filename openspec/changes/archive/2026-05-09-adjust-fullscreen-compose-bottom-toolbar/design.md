## Context

`add-note-input-fullscreen-compose` 已经把 add-memo compose 从 compact bottom sheet 扩展到 full-screen presentation，并把状态所有权保留在现有 `MemoComposerController` / `NoteInputSheet` 路径中。

当前未提交实现里，`NoteInputFullscreenCompose` 将 `MemoToolbarRow.top` 放进 full-screen header 左侧，将 `MemoToolbarRow.bottom`、visibility 和 lightweight send 放在 header 下方的第二行。用户现在确认新的方向是：full-screen 顶部只承担窗口 chrome，toolbar 回到底部并保持双层结构。

相关约束：

- 这是 presentation-only 调整，不改变 memo creation、draft、visibility、attachment、tag autocomplete、sync 或 API 行为。
- 现有 compact bottom sheet 布局继续保留。
- full-screen collapse control 的语义是返回 compact bottom sheet。
- full-screen send control 继续使用当前 30px lightweight 样式，不回到 compact sheet 的大型圆形按钮。
- Architecture phase remains `evolve_modularity`.

## Goals / Non-Goals

**Goals:**

- 将 full-screen top chrome 调整为左侧 close、右侧 collapse-to-sheet。
- 将 two-row compose toolbar 移到 full-screen 底部。
- 将底部右侧 visibility/permission 和 30px send/voice control 竖向排列，其中 send 在下方。
- 继续复用 `MemoComposeToolbarActionSpec`、`MemoToolbarPreferences` 和现有 submit/visibility callbacks。
- 更新 focused widget tests，使布局断言匹配新的 top chrome 和 bottom toolbar。

**Non-Goals:**

- 不改变 `MemoComposerController` 状态模型。
- 不移动 compose state 到新 provider。
- 不改变 default toolbar preferences。
- 不改变 memo submit、voice recording、draft persistence、attachment processing、sync 或 API route/version logic。
- 不引入商业/private hooks。
- 不修改 desktop inline compose 或 existing memo editor 的布局。

## Decisions

### Decision: Top chrome contains only close and collapse-to-sheet controls

Full-screen header should be visually quiet and stable:

```text
┌──────────────────────────────┐
│ [close]              [shrink] │
└──────────────────────────────┘
```

Rationale:

- close 和 collapse 是 presentation/window-level actions，比 Markdown toolbar 更适合 header。
- 左上角 close 满足用户明确要求。
- 右上角 collapse 保留当前 full-screen exit 语义：返回 compact bottom sheet，而不是关闭 sheet。

Alternative considered:

- 保持当前 header-left toolbar。Rejected because it mixes writing tools with window chrome and no longer matches the desired bottom-toolbar mental model.

### Decision: Bottom toolbar owns both toolbar rows

Full-screen bottom area should mirror the compact compose toolbar structure:

```text
┌──────────────────────────────┐
│ toolbar row 1          [vis] │
│ toolbar row 2         [send] │
└──────────────────────────────┘
```

Implementation direction:

- Reuse the existing full-screen toolbar strip helper or a small feature-local helper that renders visible actions for a given `MemoToolbarRow`.
- Keep toolbar action construction in `NoteInputSheet` via the existing `_buildComposeToolbarActions(...)` path.
- Avoid duplicating Markdown edit callbacks or building a second independent toolbar action list.

Alternative considered:

- Reuse `MemoComposeToolbar` directly. This may be viable only if it can support right-side vertical controls without making compact toolbar layout less clear. Prefer a full-screen-specific presentation helper if it keeps compact and full-screen layout responsibilities separated while sharing action specs.

### Decision: Visibility and send form a vertical right rail

The right side of the bottom toolbar should use:

```text
[visibility]
[send/voice]
```

Rationale:

- It keeps send visually reachable but does not consume horizontal toolbar space.
- It preserves the current lightweight full-screen send affordance.
- It lets toolbar rows keep their original horizontal scanning pattern.

The visibility button continues opening the existing visibility menu from `_visibilityMenuKey`. The send button continues calling `_submitOrVoice`.

### Decision: Editor remains the flexible middle region

The editor and preview metadata remain between top chrome and bottom toolbar:

```text
top chrome
attachment preview / linked memos / location
Expanded TextField
bottom toolbar
```

Rationale:

- Attachment preview, linked memo chips, and location state belong with the editor context, not with the toolbar chrome.
- The bottom toolbar should remain fixed at the bottom of the full-screen surface while the editor takes the remaining space.
- Existing keyboard inset handling should continue to ensure the bottom toolbar and editor remain visible above the keyboard.

### Dependency direction and modularity

Before and after:

```text
features/memos/widgets/note_input_fullscreen_compose.dart
  -> state/memos model types already passed as values
  -> state/settings toolbar preference model via compose toolbar shared types
  -> core markdown editing / palette helpers
```

This change should not introduce new imports from `state`, `application`, or `core` back into `features`. It also should not create new `state -> features`, `application -> features`, or `core -> higher-layer` dependencies.

Scoped modularity preservation:

- Keep layout code inside `features/memos/widgets/note_input_fullscreen_compose.dart`.
- Keep action construction outside the widget in the existing `NoteInputSheet` path.
- If helper extraction is needed, keep it feature-local and presentational; do not move UI concerns into `state` or `core`.
- Existing architecture guardrail coverage for note input presentation internals should remain valid.

## Risks / Trade-offs

- [Risk] Bottom toolbar plus keyboard inset may reduce available editor height on small screens. → Mitigation: keep top chrome compact, use `Expanded` for the editor, and preserve existing `MediaQuery.viewInsetsOf(context).bottom` handling.
- [Risk] Vertical right rail may create cramped tap targets if toolbar height is too small. → Mitigation: size the bottom bar around the two 30px controls plus spacing, not around a fixed 42px single-row toolbar.
- [Risk] Reusing full-screen-specific strip helpers can drift from compact toolbar behavior. → Mitigation: share `MemoComposeToolbarActionSpec` and `MemoToolbarPreferences`; only presentation differs.
- [Risk] Existing tests assert toolbar rows in the header. → Mitigation: update focused layout assertions to validate top chrome and bottom toolbar positions instead of the old placement.

## Migration Plan

No data migration is required. The change is runtime presentation-only.

Implementation can be rolled back by restoring the current `NoteInputFullscreenCompose` top-toolbar layout and associated test expectations.

## Open Questions

- None. User confirmed collapse returns to compact bottom sheet and full-screen send keeps the 30px lightweight treatment.
