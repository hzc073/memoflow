## 1. Planning

- [x] 1.1 Select memo main write primitives as the final bounded DB decoupling step.
- [x] 1.2 Map remaining `AppDatabaseWriteDao` ownership of direct `memos` table writes and supporting row reads.

## 2. Implementation

- [x] 2.1 Add `MemoWriteDbPersistence` for table-local `memos` write primitives.
- [x] 2.2 Update `AppDatabaseWriteDao` to delegate direct memo row update/insert/delete/query behavior.
- [x] 2.3 Preserve existing transaction, FTS, tag mapping, stats, lifecycle, outbox, and notification orchestration.

## 3. Guardrails

- [x] 3.1 Add memo write DB persistence to focused dependency guardrails.
- [x] 3.2 Guard against `AppDatabaseWriteDao` re-owning extracted `memos` table primitives.

## 4. Verification

- [x] 4.1 Run focused memo write/envelope and mutation/delete tests.
- [x] 4.2 Run focused architecture guardrails.
- [x] 4.3 Run `flutter analyze`.
- [x] 4.4 Run broader regression if focused checks pass.
