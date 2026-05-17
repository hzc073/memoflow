## Context

Issue #193 is triggered by the current detail hit-test shape:

```text
MemoDetailView
└─ SafeArea
   └─ MemoDocumentBody: ListView
      ├─ header: MemoDocumentPrimaryContent
      │  └─ PointerDoubleTapListener
      │     └─ rendered memo content / media
      ├─ engagement
      ├─ relations
      ├─ attachments
      └─ remaining blank scroll/body area
```

`PointerDoubleTapListener` currently sits inside `MemoDocumentPrimaryContent`, so short memo content does not make the blank lower detail body interactive. The home memo card menu has already been extracted into `memo_card_action_menu.dart` with `MemoCardActionDescriptor`, grouped sections, viewport-safe anchoring, and `showMemoCardActionPopover(globalPosition)`. This change should use that seam instead of creating a second menu style.

## Goals / Non-Goals

**Goals:**

- Long-pressing the editable memo detail body opens an action popover at the press location.
- The popover uses the same visual language as the home memo card more menu.
- The detail empty area below short or empty content is part of the long-press hit area.
- Existing detail actions keep their current semantics and mutation ownership.
- Existing child interactions remain usable.
- The implementation improves or preserves modularity in the touched detail/menu area.

**Non-Goals:**

- Do not introduce new memo actions.
- Do not change remote API behavior.
- Do not remove AppBar actions unless a later design explicitly decides to reduce top-level clutter.
- Do not make text selection, image preview, links, task toggles, or audio controls worse as an accidental side effect.

## Proposed Shape

### 1. Treat the detail menu as an action-selection adapter

The popover should return `MemoCardAction`, just like the home card menu. `MemoDetailScreen` can map each selected action to existing detail handlers:

```text
MemoCardAction.copy            -> copy memo content and show copied toast
MemoCardAction.edit            -> _edit()
MemoCardAction.togglePinned    -> _togglePinned()
MemoCardAction.reminder        -> open reminder flow if existing detail support is available, otherwise delegate via shared seam
MemoCardAction.addToCollection -> showAddMemoToCollectionSheet(...)
MemoCardAction.archive         -> _toggleArchived()
MemoCardAction.restore         -> _toggleArchived()
MemoCardAction.adjustTime      -> _adjustMemoTime()
MemoCardAction.history         -> _openVersionHistory()
MemoCardAction.delete          -> _delete()
```

The menu surface should not import repositories, controllers, or mutation services. It only describes and returns the selected action.

### 2. Reuse or generalize the home popover surface

Preferred direction:

```text
features/memos/widgets/memo_card_action_menu.dart
  - MemoCardActionDescriptor
  - MemoCardActionPopover
  - showMemoCardActionPopover(...)

features/memos/widgets/memo_detail_action_menu.dart
  - buildMemoDetailActionDescriptors(...)
  - showMemoDetailActionPopover(...)
  - detail-specific filtering/mapping only
```

This keeps detail-specific availability rules out of the home card widget while avoiding duplicate popover layout code.

An acceptable smaller implementation is to call `showMemoCardActionPopover` directly from the detail screen if the existing descriptor set matches the intended detail actions closely. If detail-specific rules diverge, introduce the focused adapter immediately rather than adding conditional detail behavior to `MemoListCard`.

### 3. Put the long-press hit area around the detail body, not only the text

The detail long-press handler should be positioned high enough to include the empty area below short content:

```text
MemoDocumentBody
└─ detail-body long-press region
   └─ ListView / content sections
```

Implementation options:

| Option | Shape | Pros | Risks |
| --- | --- | --- | --- |
| Wrap `MemoDocumentBody` output | Add a body-level `GestureDetector` or equivalent around the `ListView` | Captures blank area naturally | Must avoid stealing child gestures |
| Add `onLongPressStart` to `MemoDocumentBody` | Keep the handler near scroll/body ownership | Clearer testability and explicit API | Slight constructor churn |
| Wrap only `MemoDetailView.body` | Minimal detail body changes | Could be too broad and catch non-memo detail surfaces if reused | Harder to reason about embedded mode |

Preferred: add an explicit `onLongPressStart`/`onDetailLongPressStart` path through `MemoDocumentBody`, then wrap the `ListView` with a narrowly configured gesture region.

### 4. Preserve gesture boundaries

The hard part is not showing a menu; it is not showing it at the wrong time.

Important descendants:

- Markdown may be wrapped in `SelectionArea` when selectable.
- Images and media entries can open preview surfaces.
- Task list items can toggle state.
- Source links can launch external URLs.
- Audio rows and attachment rows have their own tap behavior.
- Error panels have retry/copy buttons.

Desired behavior:

```text
Long-press blank detail area        -> detail action popover
Long-press non-control memo surface -> detail action popover
Long-press image/control/link       -> child control wins, no detail action menu
Long-press selectable text          -> preserve text selection where the renderer claims it
Read-only detail                    -> no mutating detail action menu
Archived detail                     -> archived action subset only
```

If Flutter gesture arbitration makes selectable text and body-level long press conflict, preserve text selection first and still solve the original issue by covering blank/detail background areas. The spec should not require breaking text selection to satisfy the blank-area interaction.

### 5. Action availability

Normal editable memo:

```text
primary grid:
  copy, edit, reminder, pin/unpin, add to collection, archive

secondary:
  adjust time, history

danger:
  delete
```

Archived memo:

```text
primary:
  copy, history, restore

danger:
  delete
```

Read-only detail:

```text
No long-press mutation menu.
```

If copy/history are considered safe in read-only mode later, that should be a separate explicit decision because current detail `actions` are hidden entirely when `readOnly` is true.

## Modularity

Current phase is `evolve_modularity`; this change touches a large feature screen and a reusable menu surface. The implementation should leave the area equal or better structured by doing at least one of:

- Extract detail action descriptor/filtering into `features/memos/widgets/memo_detail_action_menu.dart`.
- Reuse the existing `MemoCardActionPopover` instead of duplicating popover UI.
- Keep action execution in the detail screen or existing mutation/provider seams; do not move writes into widgets.
- Add focused widget tests that lock the long-press/menu boundary so later changes do not spread the behavior back into ad hoc screen code.

No `state -> features`, `application -> features`, or `core -> higher-layer` imports should be introduced.

## Risks / Trade-offs

- [Risk] Long-press conflicts with text selection. Mitigation: design the handler so descendant selection/control gestures can win; if necessary, scope the body long-press to blank/background areas first.
- [Risk] Detail and home action menus diverge. Mitigation: share the popover surface and, where possible, the descriptor/action enum.
- [Risk] More logic accumulates in `memo_detail_screen.dart`. Mitigation: use a focused adapter/helper for descriptor building and keep the screen as the action executor.
- [Risk] Small viewports or long localized labels overflow. Mitigation: rely on the existing viewport-safe popover layout and existing ellipsis behavior, and add tests for clamping.
- [Risk] Archived/read-only behavior becomes inconsistent with AppBar actions. Mitigation: test normal, archived, and read-only detail states explicitly.

## Open Questions

- Should long-press on selectable markdown text open the app action menu, or should native text selection always win?
- Should read-only detail allow non-mutating actions such as copy/history, or stay consistent with the current hidden AppBar actions?
- Should the detail menu eventually replace some AppBar icons to reduce top-level clutter, or remain an additional contextual shortcut?
