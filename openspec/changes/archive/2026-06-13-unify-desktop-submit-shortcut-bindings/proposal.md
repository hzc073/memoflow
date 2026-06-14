## Why

桌面端已经提供可配置的 `DesktopShortcutAction.publishMemo`，但实际输入面并不完全一致：首页 inline compose、`NoteInputSheet` 和 quick input window 会读取配置，而 `MemoEditorScreen` 仍硬编码 `Ctrl+Enter` 保存。用户在“快捷键”设置中修改提交发送快捷键后，部分桌面编辑入口不会生效，容易被理解为“快捷键设置无法保存”。

本 change 需要统一“提交发送”语义：普通 `Enter` 继续作为多行输入换行，用户配置的提交快捷键负责直接提交/发送 memo。

## What Changes

- 统一桌面 memo 输入面的提交快捷键行为：`MemoEditorScreen`、桌面首页 inline compose、`NoteInputSheet`、desktop quick input window SHALL 使用同一份 `desktopShortcutBindings[DesktopShortcutAction.publishMemo]` 作为“提交发送”快捷键来源。
- 保留普通 `Enter` 的多行编辑语义；输入框聚焦时，plain `Enter` 不应触发提交、打开选中 memo、或离开当前输入面。
- 保留现有 `Shift+Enter` publish fallback，除非后续实现阶段发现与可配置快捷键冲突；若保留，应在 UI 文案和 tests 中明确它是 fallback。
- 明确“保存快捷键”产品语义为直接提交/发送 memo，不是保存草稿；草稿保存继续走现有 draft persistence。
- 改进 touched area 的结构：把 `publishMemo` 快捷键匹配和 primary modifier 平台映射收敛到现有 desktop shortcut seam 或 focused helper，减少编辑 surface 内部硬编码。
- 增加 focused tests 覆盖设置持久化、配置生效、普通 `Enter` 换行保护、macOS primary modifier 行为，以及 quick record system hotkey registration 不受影响。

## Capabilities

### New Capabilities

- `desktop-submit-shortcut-bindings`: 定义桌面端 memo 输入面的提交发送快捷键配置、生效范围、换行保护、fallback 语义和边界要求。

### Modified Capabilities

- `desktop-memo-editor-surface`: 桌面统一 memo editor surface 需要遵守可配置的提交发送快捷键，而不是硬编码 `Ctrl+Enter`。
- `note-input-sheet`: 桌面 note input compose surface 的提交快捷键需要与全局 desktop shortcut binding 保持一致。
- `windows-home-inline-compose-keyboard`: 已有 inline compose 键盘 ownership 规则需要明确可配置提交快捷键仍由 editor 拥有，plain `Enter` 继续换行。

## Impact

- Affected code:
  - `memos_flutter_app/lib/core/desktop/shortcuts.dart`
  - `memos_flutter_app/lib/features/settings/desktop_shortcuts_settings_screen.dart`
  - `memos_flutter_app/lib/features/memos/memo_editor_screen.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_desktop_shortcut_delegate.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_screen.dart`
  - `memos_flutter_app/lib/features/memos/note_input_sheet.dart`
  - `memos_flutter_app/lib/features/desktop/quick_input/desktop_quick_input_window.dart`
  - focused tests under `memos_flutter_app/test/core/desktop`, `test/features/memos`, `test/features/settings`, and `test/application/desktop`
- API impact: 不修改 Memos server API request/response models、route adapters、version compatibility logic，且不触碰 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`。
- Data impact: 不改变 `desktopShortcutBindings` storage schema；必要时只调整 label、helper、tests 和 behavior wiring。
- Commercial/public boundary: 不引入 subscription、billing、entitlement、paywall、StoreKit、private overlay 或 `AccessDecision.source` business branching。
- Architecture phase: 当前为 `evolve_modularity`，本 change 触及 checklist `4.` 和 `10.`：避免 shared shortcut behavior 继续隐藏在 screen/widget 文件中，并要求 touched area equal or better structured。实现阶段应通过 shared desktop shortcut helper 或 guardrail/test 防止硬编码提交快捷键再次分叉。
