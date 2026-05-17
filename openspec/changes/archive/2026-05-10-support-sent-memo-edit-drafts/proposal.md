## Why

已发送笔记在编辑中退出时，目前只能依赖隐藏的 editor recovery draft，下次进入同一条 memo 编辑时才可能恢复；用户无法从可见的草稿箱继续这类未保存修改。这个 change 让“编辑已发送笔记但暂不保存”的工作流进入 Draft Box，并避免误创建重复 memo。

## What Changes

- Add an edit-draft workflow for sent memos: when editing an existing memo with unsaved changes, closing/back/Esc prompts the user to continue editing, discard changes, or add the edit draft to Draft Box.
- Store edit drafts as visible Draft Box entries bound to the original memo, so saving from the restored draft updates that original memo instead of creating a new memo.
- Ensure one original memo has at most one visible edit draft; later saves to Draft Box update the existing edit draft for that memo.
- Update Draft Box selection behavior so create drafts still open the create-note compose surface, while edit drafts open the existing-memo editor.
- Keep memo action menus unchanged; this change does not add a “add to draft box” menu action.
- Preserve hidden recovery behavior only as crash/accidental-close protection where useful, while visible Draft Box persistence remains an explicit user choice from the unsaved-exit prompt.

## Capabilities

### New Capabilities
- `sent-memo-edit-drafts`: 已发送 memo 的可见编辑草稿行为，包括退出提示、原 memo 绑定、单 memo 单编辑草稿、恢复后保存更新原 memo。

### Modified Capabilities
- `draft-box-navigation`: Draft Box selection must route by draft type: create drafts continue through note input creation, edit drafts open the bound existing memo editor.

## Impact

- Active architecture phase: `evolve_modularity`.
- Modularity checklist items touched: `4.` shared draft/editor behavior should not remain hidden inside screen widgets, `6.` Draft Box-to-editor collaboration should use navigation/provider seams, `7.` touched write paths need a clear repository/mutation owner, and `8.` guardrails/tests should protect the new draft routing behavior.
- Affected app areas:
  - `memos_flutter_app/lib/data/models/compose_draft.dart`
  - `memos_flutter_app/lib/data/db/...` local `compose_drafts` schema/migration paths
  - `memos_flutter_app/lib/state/memos/compose_draft_provider.dart`
  - `memos_flutter_app/lib/state/memos/memo_editor_draft_provider.dart`
  - `memos_flutter_app/lib/features/memos/memo_editor_screen.dart`
  - `memos_flutter_app/lib/features/memos/draft_box_screen.dart`
  - `memos_flutter_app/lib/features/memos/draft_box_navigation_screen.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_screen.dart`
- No server API route/version changes are intended.
- Expected verification includes focused model/repository tests, Draft Box routing widget tests, memo editor unsaved-exit prompt tests, and existing architecture guardrails.
