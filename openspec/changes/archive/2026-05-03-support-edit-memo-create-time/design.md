## Context

当前 memo 数据模型同时存在 `createTime` 与 `displayTime`，列表、详情正文和查询排序主要使用 `effectiveDisplayTime = displayTime ?? createTime`。这意味着如果只修改 `createTime` 而保留旧的 `displayTime`，用户看到的列表时间和排序可能不会变化；如果只修改 `displayTime`，统计、导出或按创建时间理解的场景又可能继续保留旧值。

现有 UI 结构中：

- 列表卡片已有 memo-level `PopupMenuButton`，包含 copy、pin、edit、history、reminder、collection、archive、delete。
- 详情页 AppBar 已有多个直接图标动作，继续增加稀有动作图标会加重顶部栏。
- 编辑器底部 toolbar 面向 Markdown/content insertion，visibility 是当前唯一 metadata 控件；时间调整属于 memo metadata，而不是正文编辑能力。
- `MemosApi.updateMemo` 已暴露 `createTime` / `displayTime` 参数，但 `update_memo` outbox handling 当前主要同步 content、visibility、pin、state、location、relations、attachments。

Architecture phase is `evolve_modularity`. The change touches feature UI and memo write/sync seams. It should preserve existing dependency direction:

- `features/memos` may depend on `state/memos` providers/controllers.
- `state/memos` MUST NOT import `features/memos`.
- `application` and `core` layers MUST NOT gain imports from `features/memos` or timestamp UI code.
- API-related edits under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api` require explicit user approval before implementation.

## Goals / Non-Goals

**Goals:**

- Provide a discoverable per-memo UI entry for adjusting an existing memo's time.
- Make the user-facing action describe the visible timeline behavior, while preserving the user's intent to adjust the memo creation timestamp.
- Update local display/order consistently after save.
- Route timestamp mutation through an owned memo state/service seam, not directly from UI widgets into database or API code.
- Queue remote sync with timestamp payloads when remote sync is allowed.
- Handle server capability differences without silently claiming an unsupported remote creation-time change succeeded.
- Add focused tests for UI entry, local ordering/display update, and outbox payload behavior.

**Non-Goals:**

- Change memo creation flow or add scheduled creation.
- Add a toolbar action to the Markdown editor.
- Redesign memo history, reminder, archive, or collection actions.
- Add commercial/private extension hooks.
- Change backend API contracts beyond using existing supported timestamp fields.
- Implement broad sync architecture rewrites.

## Decisions

### Decision 1: Use "调整时间 / Adjust time" as the user-facing action

The menu should say "调整时间" rather than "修改创建时间" because the UI result users care about is the memo's timeline placement and visible timestamp. The sheet can explain that saving changes the memo's creation/timeline time.

Alternative considered: label the action "修改创建时间". This is precise to the original request but risky because the app already has `displayTime`, and a raw create-time-only action could fail to change the visible list time.

Alternative considered: label the action "修改显示时间". This matches `displayTime` too narrowly and may feel like a cosmetic override instead of changing the memo's actual time.

### Decision 2: Primary entry lives in the memo object action menu

The primary entry should be added to the existing memo card action menu near `edit`, because timestamp adjustment is a low-frequency object action like edit/history/reminder/archive.

Recommended menu order:

```text
Copy
Pin / Unpin
Edit
Adjust time...
History
Reminder
Add to collection
Archive
Delete
```

The detail page should expose the same capability without adding another AppBar icon. A lightweight affordance on the displayed timestamp row is preferable: tapping the timestamp/metadata row opens the same time adjustment surface when the memo is editable. If that proves too hidden during implementation, a detail overflow menu is a safer fallback than another direct AppBar icon.

Alternative considered: add a dedicated AppBar icon in detail. This competes with existing edit/history/pin/collection/archive/delete icons and makes a rare action too prominent.

Alternative considered: put the action in the editor toolbar. The toolbar is for content editing and insertion; timestamp mutation is metadata and would increase toolbar clutter.

Alternative considered: use the floating action stack. The stack is list-level navigation/collapse behavior, not per-memo metadata editing.

### Decision 3: Save a single selected timestamp into both `create_time` and `display_time`

For this feature, the selected value should be treated as the memo's canonical user-adjusted time. Local persistence should update both `createTime` and `displayTime` to the selected timestamp so that:

- list/detail timestamp display changes immediately,
- `COALESCE(display_time, create_time)` ordering changes immediately,
- stats and other create-time-based local reads do not contradict the visible timeline,
- later remote reconciliation has an explicit display timestamp rather than relying on fallback behavior.

Alternative considered: update only `createTime`. This can leave `displayTime` unchanged and make the UI appear broken.

Alternative considered: update only `displayTime`. This changes the timeline but does not satisfy the "creation time" intent and can leave stats/export semantics inconsistent.

Alternative considered: expose separate "created time" and "display time" advanced controls. This is more powerful but too complex for the initial UX and creates confusing states for most users.

### Decision 4: Add a focused memo time mutation seam

The implementation should add or extend a state-layer controller/service method such as `adjustMemoTime(...)` that accepts the memo and selected timestamp, updates local storage through `AppDatabase.upsertMemo`, and enqueues a timestamp-aware `update_memo` payload.

Dependency direction before:

- `features/memos` invokes memo controllers/services for edit, pin, archive, delete, reminder, and collection behaviors.
- `state/memos` owns mutation orchestration and outbox enqueueing.
- `data/db` owns SQLite persistence.
- `data/api` owns server request formatting.

Dependency direction after:

- `features/memos` invokes the new timestamp mutation seam.
- `state/memos` remains the owner of write/outbox behavior and does not import UI.
- `data/db` receives timestamp values through existing persistence methods.
- `data/api` is used through existing API methods unless implementation reveals a necessary API compatibility change, which requires explicit user approval first.

This keeps the touched area equal or better structured under `evolve_modularity` by preventing timestamp write logic from spreading into widgets/screens.

### Decision 5: Make remote sync capability-aware

The outbox payload should carry explicit timestamp fields, e.g. `create_time` and `display_time` seconds. The remote sync handler should parse those fields and pass them to `api.updateMemo` when syncing an `update_memo` task.

For servers that support `createTime` updates, sync both `createTime` and `displayTime`. If a server does not support remote create-time updates but supports display-time updates, syncing `displayTime` can still keep the remote timeline close to local visible behavior. If neither timestamp path succeeds, the app should preserve local state and surface sync failure through existing sync-state/error behavior rather than silently dropping the timestamp mutation.

Alternative considered: ignore remote sync and keep the change local-only. This would surprise users with remote-backed accounts.

Alternative considered: block the UI whenever remote support is uncertain. This is too conservative for local mode and for existing capability probing paths.

## Risks / Trade-offs

- [Risk] The label "调整时间" may not make it obvious that creation time changes. → Mitigation: sheet copy should mention creation/timeline time and ordering.
- [Risk] Updating both `create_time` and `display_time` removes any existing distinction between raw creation time and display time for that memo. → Mitigation: initial UX intentionally models one user-facing memo time; advanced separate controls remain out of scope.
- [Risk] Some server versions may reject `createTime` updates. → Mitigation: use existing capability checks and preserve sync error visibility when remote mutation cannot be completed.
- [Risk] Adding another action to the card menu increases menu length. → Mitigation: place it near `Edit`, avoid extra top-level icons, and keep destructive actions separated.
- [Risk] Timestamp mutation may affect statistics, search ranges, collections, and widgets. → Mitigation: update the canonical local timestamp consistently and add focused regression coverage for list ordering/display.
- [Risk] API compatibility changes could violate collaboration constraints. → Mitigation: prefer existing API methods; obtain explicit user approval before editing API-related code or tests.

## Migration Plan

1. Add UI entry points and a shared time adjustment surface under `features/memos`.
2. Add/extend a memo state-layer mutation seam for timestamp adjustment.
3. Persist selected timestamp into both local `create_time` and `display_time`.
4. Extend `update_memo` outbox payload and handler to carry timestamp fields.
5. Add focused widget/unit tests for entry visibility, timestamp display/order update, and outbox timestamp payloads.
6. Run focused tests first, then `flutter analyze` and relevant broader tests from `memos_flutter_app`.

Rollback strategy: remove the UI entry and timestamp mutation seam; existing memo edit/pin/archive/delete paths remain unchanged. If remote timestamp sync causes compatibility issues, keep local persistence guarded while disabling timestamp fields in the outbox handler until compatibility is clarified.

## Open Questions

- Should the detail timestamp row be directly tappable in the first implementation, or should detail use an overflow menu for better discoverability? The current recommendation is timestamp-row affordance, with overflow as fallback if testing shows discoverability or accessibility issues.
- Should remote servers that reject `createTime` but accept `displayTime` be considered a successful partial sync or a visible sync warning? The design leans toward preserving local state and using existing sync-state/error behavior for unsupported creation-time sync.
