## 1. Planning

- [x] 1.1 Select core memo schema as the next bounded DB decoupling step.
- [x] 1.2 Map remaining `AppDatabase` ownership of `memos`, legacy `attachments`, and memo column migrations.

## 2. Implementation

- [x] 2.1 Add `MemoCoreDbPersistence` for core memo schema, legacy attachment schema, memo column migrations, memo count, and legacy attachment memo-UID rename.
- [x] 2.2 Update `AppDatabase` lifecycle and `countMemos` to delegate core memo persistence details.
- [x] 2.3 Update `AppDatabaseWriteDao` memo UID rename flow to delegate legacy attachment table updates.

## 3. Guardrails

- [x] 3.1 Add core memo DB persistence to focused dependency guardrails.
- [x] 3.2 Guard against `AppDatabase` re-owning core memo schema and migration SQL.
- [x] 3.3 Guard against `AppDatabaseWriteDao` re-owning legacy attachment table-local SQL.

## 4. Verification

- [x] 4.1 Run focused DB migration tests.
- [x] 4.2 Run focused memo write/envelope and sync tests covering memo UID/write behavior.
- [x] 4.3 Run focused architecture guardrails.
- [x] 4.4 Run `flutter analyze`.
- [x] 4.5 Run broader regression if focused checks pass.
