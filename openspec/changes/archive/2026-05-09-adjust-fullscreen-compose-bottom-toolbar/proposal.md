## Why

当前未提交的 `NoteInputSheet` full-screen compose 已经解决了长文本输入空间不足的问题，但 toolbar 被放在顶部后，写作区域和顶部窗口控制混在一起，视觉重心偏高，也偏离用户希望保留的原先双层底部工具栏心智模型。

这个变更将 full-screen compose 调整为“顶部只放关闭/缩放 chrome，底部承载双层 compose toolbar 和发送/权限控制”，让写作模式更接近原底部 sheet 的操作节奏，同时继续保留全屏编辑空间。

## What Changes

- 调整 full-screen compose 顶部 chrome：
  - 左上角显示关闭按钮，触发现有 draft-aware close 行为。
  - 右上角显示缩小/恢复按钮，点击后返回 compact bottom sheet。
  - 顶部不再承载 Markdown toolbar actions，也不恢复 `Create memo` 标题。
- 将 full-screen compose 的 toolbar actions 改回底部双层布局：
  - 第一行显示 `MemoToolbarRow.top` actions。
  - 第二行显示 `MemoToolbarRow.bottom` actions。
  - 继续复用现有 `MemoComposeToolbarActionSpec` 和 `MemoToolbarPreferences`，不新增独立 action 构造路径。
- 将底部 toolbar 右侧控制改成竖向排列：
  - visibility/permission button 在上。
  - 30px lightweight send/voice button 在下。
- 保持 full-screen compose 的现有行为不变：
  - submit/voice path 不变。
  - visibility menu 不变。
  - draft 保存/关闭行为不变。
  - text、selection、attachments、linked memos、location、tag autocomplete state 在 compact/full-screen 切换中继续保留。
- 更新 focused widget coverage，验证 full-screen 顶部 chrome、底部 toolbar 行、右侧竖向 visibility/send 控制，以及既有行为保留。

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `note-input-sheet`: Revise the full-screen add-memo compose layout so toolbar actions move to the bottom, while top chrome owns close and collapse-to-sheet controls.

## Impact

- Affected runtime areas:
  - `memos_flutter_app/lib/features/memos/widgets/note_input_fullscreen_compose.dart`
  - `memos_flutter_app/lib/features/memos/note_input_sheet.dart` only if constructor keys or call-site wiring need small presentational adjustments
- Affected tests:
  - `memos_flutter_app/test/features/memos/note_input_sheet_fullscreen_test.dart`
  - Existing architecture guardrail tests should remain valid because the change stays in `features/memos` presentation code.
- APIs, persistence, sync, database schema, upload handling, and request/response models are not affected.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched:
  - `4.` No reused shared domain logic hidden inside screen or widget files.
  - `7.` Touched write paths have clear owners such as services, repositories, or mutation seams.
  - `10.` Every change touching a coupled area leaves that area equal or better structured than before.
- Scoped modularity stance: keep this as a presentation-only adjustment inside `features/memos`; do not move state into new providers or duplicate compose action construction.
