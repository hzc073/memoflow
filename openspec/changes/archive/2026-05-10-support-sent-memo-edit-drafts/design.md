## Context

当前 Draft Box 的可见数据来自 `compose_drafts` SQLite 表和 `ComposeDraftRecord`，主要服务“新建 memo 但还没有发送”的 create draft。已发送 memo 的编辑器 `MemoEditorScreen(existing: memo)` 另有一套 `MemoEditorDraftRepository`，把未保存编辑内容按 memo uid 写入 secure storage，作为隐藏 recovery draft；它不进入 Draft Box，也不能从导航草稿箱继续。

用户确认的产品语义是 B 方案：已发送 memo 的编辑草稿必须绑定原 memo，从 Draft Box 恢复后保存应更新原 memo，而不是创建新 memo。入口只来自编辑已发送 memo 时退出的确认弹窗，不新增 memo 菜单操作。同一条原 memo 在 Draft Box 内最多一条 edit draft。

本 change 会触及 draft persistence、memo editor、Draft Box navigation 和本地 schema，属于 `evolve_modularity` 阶段下的耦合区域。设计目标是把“编辑草稿”的数据映射放到稳定 helper/repository seam，而不是继续把共享草稿逻辑藏在 screen widget 内。

## Goals / Non-Goals

**Goals:**
- 在编辑已发送 memo 且存在未保存修改时，关闭/返回/Esc 统一进入“继续编辑 / 放弃更改 / 加入草稿箱”决策。
- Draft Box 同时展示 create drafts 和 sent memo edit drafts，并让 edit drafts 有清晰的“编辑草稿”语义。
- Edit draft 保存原 memo 绑定信息；从 Draft Box 打开后进入 `MemoEditorScreen(existing)`，保存更新原 memo 并移除该 edit draft。
- 同一 workspace 内同一原 memo 只保留一条 edit draft，后续加入草稿箱更新同一记录。
- 迁移现有 create drafts 时保持行为不变，并让 backup/config transfer/migration 路径能够序列化新增可选字段。
- 通过 helper/provider/repository seam 改善 touched area，避免引入新的 `state -> features`、`application -> features` 或 `core -> higher-layer` 依赖。

**Non-Goals:**
- 不新增 memo card/action menu 的“加入草稿箱”入口。
- 不改变 server API route/version compatibility；此 change 不修改 `lib/data/api`。
- 不改变 create draft 的发送语义：create draft 仍然创建新 memo。
- 不设计多人协作或跨设备冲突解决策略；只记录足够的 base memo metadata，避免明显误路由或误创建。
- 不重构整个 memo editor UI；只抽出本 change 需要共享的 draft session mapping。

## Decisions

### Decision: Extend visible compose drafts with a draft kind

Add a typed draft concept to `ComposeDraftRecord` / `ComposeDraftSnapshot`, for example:

```text
ComposeDraftKind.createMemo
ComposeDraftKind.editMemo

create draft:
  kind = createMemo
  targetMemoUid = null
  save action = create memo

edit draft:
  kind = editMemo
  targetMemoUid = original LocalMemo.uid
  base metadata = original update time / content fingerprint where available
  save action = update target memo
```

`compose_drafts` should receive additive columns with safe defaults, such as `draft_kind TEXT NOT NULL DEFAULT 'create_memo'`, `target_memo_uid TEXT`, and optional base metadata. Existing rows become `create_memo` automatically. Repository APIs should keep `saveSnapshot(...)` as the create-draft path and add explicit methods such as `saveEditDraft(...)`, `getEditDraftForMemo(...)`, and `deleteEditDraftForMemo(...)`.

To enforce “one edit draft per original memo”, prefer repository-level upsert by `(workspace_key, target_memo_uid)` and, if SQLite support in the local schema path is suitable, add a unique partial index for `draft_kind = 'edit_memo'`.

Alternatives considered:
- Keep edit drafts only in `MemoEditorDraftRepository`: rejected because Draft Box, backup, and navigation would still not see them.
- Create a second `memo_edit_drafts` table: rejected for now because it duplicates listing, deletion, backup, migration, and Draft Box UI behavior.
- Treat edit drafts as normal create drafts containing copied content: rejected because saving would create duplicate memos and violate the confirmed B方案.

### Decision: Preserve both existing attachments and pending attachments

Edit drafts need two attachment channels:

```text
existingAttachments: remote/server/local-cache attachments already on original memo
pendingAttachments: local staged files added while editing the draft
```

Current `ComposeDraftAttachment` represents pending local attachments. Edit drafts also need serialized `Attachment` records for the original memo attachments that remain in the draft. A practical model is to extend `ComposeDraftSnapshot` with `existingAttachments` and add a matching `existing_attachments_json TEXT NOT NULL DEFAULT '[]'` column. Create drafts leave this empty.

This avoids the main failure mode: restoring an edit draft and accidentally treating all original attachments as missing, or trying to upload already-existing remote attachments as new pending files.

### Decision: Extract memo editor draft session mapping

Move edit-draft snapshot construction/restoration into a stable helper, for example `state/memos/memo_editor_draft_session.dart`, owned by state/data model types rather than feature widgets. The helper should map:

```text
MemoEditor current state
  -> ComposeDraftSnapshot(kind: editMemo, targetMemoUid, content, visibility,
                          location, existingAttachments, pendingAttachments)

ComposeDraftRecord(kind: editMemo)
  -> MemoEditor initial draft state
```

Before: `MemoEditorScreen` owns hidden JSON payload construction and restoration details internally.

After: `MemoEditorScreen` remains the presentation/controller host, while reusable edit draft mapping is covered by focused unit tests and can be used by Draft Box routing without duplicating state reconstruction.

### Decision: Route every editor close through one close-request seam

`MemoEditorScreen` should centralize close handling in a method like `_requestCloseEditor()`. Page back, app bar close, desktop modal close, and Escape should call that seam. For an existing memo:

```text
if no unsaved editor state:
  close normally
else:
  show dialog:
    Continue editing -> stay open
    Discard changes -> clear relevant recovery/edit draft state and close
    Add to Draft Box -> save/update visible edit draft, clear hidden recovery, close
```

For new memo editor usage, existing draft behavior should remain unchanged. Hidden secure-storage recovery can continue protecting crashes or accidental unmounts, but the visible Draft Box entry should only be created by the explicit “Add to Draft Box” choice.

### Decision: Draft Box selection routes by draft kind

Navigation-launched Draft Box currently returns only a draft id and opens `NoteInputSheet(initialDraftUid: ...)`. That should become a typed selection flow:

```text
createMemo draft selected
  -> NoteInputSheet(initialDraftUid)

editMemo draft selected
  -> load target LocalMemo
  -> MemoEditorScreen(existing: targetMemo, initial edit draft record)
```

The routing belongs in the feature/navigation layer (`DraftBoxNavigationScreen` / `MemosListScreen` seams), not in lower state providers. If the target memo cannot be loaded, the app should not fall back to create-memo behavior; it should keep the draft and present an unavailable-target message with delete still available from Draft Box.

### Decision: Keep write ownership in repository/mutation seams

All DB writes for visible drafts should continue through `ComposeDraftRepository` and `ComposeDraftMutationService`, preserving the existing guardrail that prevents direct DB writes from the provider. Widget code should request “save edit draft” or “delete edit draft” from the repository rather than calling `AppDatabase` directly.

Backup/config transfer should serialize unknown-safe optional fields for edit drafts. Existing create drafts must round-trip unchanged.

## Risks / Trade-offs

- [Risk] Additive schema fields may make downgrade behavior confusing if an older app sees an edit draft as a create draft. -> Mitigation: use explicit `draft_kind`, keep defaults for existing rows, and document downgrade as unsupported for newly-created edit drafts.
- [Risk] Original memo is deleted, archived, or not loaded when the edit draft is selected. -> Mitigation: never open edit drafts as create drafts; show target unavailable and leave the draft deletable.
- [Risk] Remote sync changes the original memo after the edit draft is saved. -> Mitigation: store base update/fingerprint metadata and keep save/update routed through the normal memo editor mutation path; conflict UI can be added later if needed.
- [Risk] Attachment handling may lose original attachments if edit drafts reuse pending attachment fields. -> Mitigation: store existing attachments separately from pending local draft attachments and add unit tests for both.
- [Risk] More behavior in `MemoEditorScreen` could worsen the screen hotspot. -> Mitigation: extract edit-draft mapping into a helper and keep persistence writes in `ComposeDraftRepository`; add focused tests so the screen only coordinates UI decisions.

## Migration Plan

1. Add nullable/defaulted local schema columns for draft kind, target memo metadata, and existing attachments.
2. Update `ComposeDraftRecord.fromRow/toRow` so missing columns decode as create drafts.
3. Update WebDAV/config transfer draft serialization to include new optional fields and tolerate absent fields.
4. Add repository methods for edit draft upsert/delete/read by target memo.
5. Wire memo editor close prompt and Draft Box typed routing.
6. Run focused tests plus `flutter analyze` and `flutter test` before implementation is considered complete.

Rollback is straightforward for code changes, but data downgrade is not guaranteed for edit drafts created under the new schema. Existing create drafts remain compatible by defaulting to `create_memo`.

## Open Questions

- Exact localized copy can be finalized during implementation, but the required choices are fixed: continue editing, discard changes, and add to Draft Box.
