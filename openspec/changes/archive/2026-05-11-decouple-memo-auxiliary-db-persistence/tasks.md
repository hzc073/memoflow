## 1. Planning

- [x] 1.1 Review Batch 5 small DB tables from `db-persistence-boundaries`.
- [x] 1.2 Select `memo_reminders`, `import_history`, and `memo_clip_cards` for this extraction; defer stats cache to a dedicated follow-up.
- [x] 1.3 Map selected table ownership in `AppDatabase` and `AppDatabaseWriteDao`.

## 2. Implementation

- [x] 2.1 Add `MemoAuxiliaryDbPersistence` for selected small-table schema, reads, and row primitives.
- [x] 2.2 Update `AppDatabase` lifecycle/read helpers to delegate selected small-table behavior.
- [x] 2.3 Update `AppDatabaseWriteDao` write flows to delegate selected small-table primitives while preserving transactions, notifications, and clip-card search refresh.

## 3. Guardrails

- [x] 3.1 Add memo auxiliary DB persistence to focused dependency guardrails.
- [x] 3.2 Guard against `AppDatabase` re-owning selected small-table schema/read SQL.
- [x] 3.3 Guard against `AppDatabaseWriteDao` re-owning selected small-table row primitives.

## 4. Verification

- [x] 4.1 Run focused DB migration, clip-card, import, and reminder-related tests.
- [x] 4.2 Run focused architecture guardrails.
- [x] 4.3 Run `flutter analyze`.
- [x] 4.4 Run broader regression if focused checks pass.
