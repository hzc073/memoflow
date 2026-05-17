## 1. Planning

- [x] 1.1 Review `db-persistence-boundaries` and select Batch 1: Tags.
- [x] 1.2 Map tag persistence ownership in `AppDatabase`, `AppDatabaseWriteDao`, and `TagRepository`.

## 2. Implementation

- [x] 2.1 Add `TagDbPersistence` for `tags`, `tag_aliases`, `memo_tags`, tag reads, tag resolution, snapshot row primitives, and memo/tag mapping primitives.
- [x] 2.2 Update `AppDatabase` lifecycle/facade/backfill code to delegate tag table-local behavior to `TagDbPersistence`.
- [x] 2.3 Update `AppDatabaseWriteDao` tag mutation flows to use `TagDbPersistence` primitives while preserving transaction and notification ownership.
- [x] 2.4 Update `TagRepository` read paths to use `TagDbPersistence`.

## 3. Guardrails

- [x] 3.1 Add `TagDbPersistence` to focused DB persistence dependency guardrails.
- [x] 3.2 Guard against `AppDatabase` re-owning extracted tag schema/table-local helpers.

## 4. Verification

- [x] 4.1 Run focused tag tests.
- [x] 4.2 Run focused DB/architecture tests touched by the change.
- [x] 4.3 Run `flutter analyze` if focused tests pass.
