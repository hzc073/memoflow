## Why

`AppDatabase` 仍然直接承载 outbox schema、migration、read queries、payload parsing，以及 sync queue 状态机相关 SQL；`AppDatabaseWriteDao` 同时混合 outbox mutation primitives 和 memo/local-library 业务写入。现在 compose draft 与 memo search persistence 已完成拆分，outbox 是下一个高收益 DB hotspot：它影响 local sync、remote sync、desktop write proxy、Draft Box/memo mutation flows，继续内嵌会让 `AppDatabase` 难以收敛为 facade/lifecycle owner。

当前架构阶段是 `evolve_modularity`。本 change 触碰 modularity checklist item 7、8、9、10，并通过 scoped persistence seam extraction 改善 item 7，同时用 guardrail 防止 outbox persistence 重新向 `features/`、`state/`、`application/` 泄漏。

## What Changes

- Add a focused outbox DB persistence owner under `memos_flutter_app/lib/data/db/` for outbox table creation, additive column ensure logic, legacy error-chain migration, payload memo-uid extraction helpers, read queries, and mutation primitives.
- Keep existing `AppDatabase` public methods and desktop write-proxy operation names stable, so local/remote desktop write routing remains unchanged.
- Keep transaction ownership in `AppDatabaseWriteDao`, matching the existing architecture guardrail that restricts direct `.transaction(` usage.
- Move outbox read/count/list-by-memo logic out of the main `AppDatabase` implementation while preserving returned row maps, ordering, derived attention fields, and retry/quarantine semantics.
- Move outbox enqueue/claim/mark/retry/delete/rewrite primitives out of `AppDatabaseWriteDao` as executor-based helpers while preserving `notifyDataChanged` behavior in write owners.
- Add or tighten architecture guardrails that protect the new outbox persistence seam and prevent `AppDatabase` from re-owning outbox SQL details.
- No server API route/version compatibility files are in scope.
- No user-visible sync behavior, outbox state codes, desktop write envelope operation names, or payload shapes are intended to change.

## Capabilities

### New Capabilities
- `outbox-db-persistence`: Defines the local SQLite outbox persistence contract, including schema compatibility, state transition persistence, payload memo-uid extraction, desktop write-proxy compatibility, and modular boundary expectations.

### Modified Capabilities

## Impact

- Affected app files are expected to be primarily:
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - `memos_flutter_app/lib/data/db/app_database_write_dao.dart`
  - new outbox persistence file(s) under `memos_flutter_app/lib/data/db/`
  - architecture tests under `memos_flutter_app/test/architecture/`
- Focused verification should cover DB write envelope tests, migration tests, sync queue tests, local/remote sync outbox tests, architecture guardrails, `flutter analyze`, and `flutter test`.
- Existing public `AppDatabase` outbox API remains available during this change to avoid broad state/application rewrites.
