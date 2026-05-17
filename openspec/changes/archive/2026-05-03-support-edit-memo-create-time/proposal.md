## Why

用户希望能把已有 memo 调整到更准确的时间点，例如补录旧笔记、导入后校正时间线、或修正误创建的时间。当前列表和详情页展示 `effectiveDisplayTime`，但没有面向单条 memo 的显式入口来修改时间，导致时间线整理只能依赖创建/导入时的值。

## What Changes

- Add a per-memo "调整时间 / Adjust time" capability reachable from memo object actions.
- Provide a dedicated time adjustment surface for selecting date and time, with clear copy about timeline ordering/display effects.
- Persist the selected time locally and queue remote sync when the current server capability supports the relevant timestamp update path.
- Keep the feature scoped to public runtime code and existing memo mutation seams; do not add commercial/private hooks.
- Preserve existing edit-content, reminder, history, archive, delete, and floating-list action behavior.

## Capabilities

### New Capabilities

- `memo-time-adjustment`: Allows users to adjust an existing memo's timeline timestamp through memo-level UI and have the changed timestamp reflected consistently in list/detail display and sync state.

### Modified Capabilities

- None.

## Impact

- Affected UI: `memos_flutter_app/lib/features/memos/widgets/memos_list_memo_card.dart`, `memos_flutter_app/lib/features/memos/memo_detail_screen.dart`, and likely a small feature-local sheet/dialog under `memos_flutter_app/lib/features/memos/`.
- Affected state/write seams: memo editor or mutation-controller path under `memos_flutter_app/lib/state/memos/`, keeping write ownership outside UI widgets.
- Affected persistence/sync: existing SQLite memo timestamp fields and existing `update_memo` outbox handling may need to carry timestamp payloads.
- Affected API behavior: existing `MemosApi.updateMemo` already has timestamp parameters, but any API-related code changes require explicit user approval before editing.
- Architecture phase: `evolve_modularity`. This change touches feature UI and memo write/sync seams, but should not introduce `state -> features`, `application -> features`, or `core -> higher-layer` dependencies. If a coupled area is touched, the implementation should leave it equal or better structured by routing timestamp mutation through an owned service/controller seam rather than embedding write logic in screens/widgets.
