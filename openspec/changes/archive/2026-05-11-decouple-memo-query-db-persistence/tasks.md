## 1. Planning

- [x] 1.1 Select memo read/export queries as the next bounded DB decoupling step.
- [x] 1.2 Map remaining `AppDatabase` ownership of memo query SQL.

## 2. Implementation

- [x] 2.1 Add `MemoQueryDbPersistence` for memo read/export query primitives.
- [x] 2.2 Update `AppDatabase` memo read/export facade methods to delegate query behavior.
- [x] 2.3 Update `AppDatabaseWriteDao` tag snapshot flow to delegate memo tag row reads.

## 3. Guardrails

- [x] 3.1 Add memo query DB persistence to focused dependency guardrails.
- [x] 3.2 Guard against `AppDatabase` re-owning extracted memo query SQL.

## 4. Verification

- [x] 4.1 Run focused memo search/query and export-related tests.
- [x] 4.2 Run focused architecture guardrails.
- [x] 4.3 Run `flutter analyze`.
- [x] 4.4 Run broader regression if focused checks pass.
