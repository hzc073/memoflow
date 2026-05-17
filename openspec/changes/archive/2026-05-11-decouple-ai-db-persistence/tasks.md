## 1. Planning

- [x] 1.1 Review `db-persistence-boundaries` and select Batch 3: AI Tables.
- [x] 1.2 Map AI persistence ownership in `AppDatabase`, `AppDatabaseWriteDao`, and `AiAnalysisRepository`.

## 2. Implementation

- [x] 2.1 Add `AiDbPersistence` for AI table schema, indexes, additive columns, and row primitives.
- [x] 2.2 Update `AppDatabase` AI lifecycle helpers to delegate table-local schema behavior.
- [x] 2.3 Update `AppDatabaseWriteDao` AI write flows to use the persistence seam while preserving transactions and notifications.

## 3. Guardrails

- [x] 3.1 Add AI DB persistence to focused dependency guardrails.
- [x] 3.2 Guard against `AppDatabase` re-owning extracted AI schema SQL.
- [x] 3.3 Guard against `AppDatabaseWriteDao` re-owning extracted AI table-local write SQL.

## 4. Verification

- [x] 4.1 Run focused AI and DB migration tests.
- [x] 4.2 Run focused architecture guardrails.
- [x] 4.3 Run `flutter analyze`.
- [x] 4.4 Run broader regression if focused checks pass.
