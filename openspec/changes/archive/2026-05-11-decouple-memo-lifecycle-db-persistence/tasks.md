## 1. Planning

- [x] 1.1 Review `db-persistence-boundaries` and select Batch 2: Memo Lifecycle Tables.
- [x] 1.2 Map lifecycle persistence ownership in `AppDatabase` and `AppDatabaseWriteDao`.

## 2. Implementation

- [x] 2.1 Add `MemoLifecycleDbPersistence` for lifecycle table schema and row primitives.
- [x] 2.2 Update `AppDatabase` lifecycle/backfill/read helpers to delegate lifecycle table-local behavior.
- [x] 2.3 Update `AppDatabaseWriteDao` lifecycle write flows to use the persistence seam while preserving transaction and notification ownership.

## 3. Guardrails

- [x] 3.1 Add lifecycle DB persistence to focused dependency guardrails.
- [x] 3.2 Guard against `AppDatabase` re-owning extracted lifecycle SQL.

## 4. Verification

- [x] 4.1 Run focused lifecycle and DB tests.
- [x] 4.2 Run focused architecture guardrails.
- [x] 4.3 Run `flutter analyze` if focused tests pass.
