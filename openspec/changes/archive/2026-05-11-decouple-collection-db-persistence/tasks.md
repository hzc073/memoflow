## 1. Planning

- [x] 1.1 Review `db-persistence-boundaries` and select Batch 4: Collections.
- [x] 1.2 Map collection persistence ownership in `AppDatabase`, `AppDatabaseWriteDao`, and `CollectionsRepository`.

## 2. Implementation

- [x] 2.1 Add `CollectionDbPersistence` for collection schema, indexes, reader-progress columns, and reader-progress row primitives.
- [x] 2.2 Update `AppDatabase` collection lifecycle/read helpers to delegate table-local behavior.
- [x] 2.3 Update `AppDatabaseWriteDao` reader-progress write flows to use the persistence seam while preserving no-notify behavior.

## 3. Guardrails

- [x] 3.1 Add collection DB persistence to focused dependency guardrails.
- [x] 3.2 Guard against `AppDatabase` re-owning extracted collection schema SQL.
- [x] 3.3 Guard against `AppDatabaseWriteDao` re-owning reader-progress table-local write SQL.

## 4. Verification

- [x] 4.1 Run focused collection and DB migration tests.
- [x] 4.2 Run focused architecture guardrails.
- [x] 4.3 Run `flutter analyze`.
- [x] 4.4 Run broader regression if focused checks pass.
