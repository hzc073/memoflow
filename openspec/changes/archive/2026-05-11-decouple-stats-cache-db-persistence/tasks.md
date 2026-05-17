## 1. Planning

- [x] 1.1 Select stats cache as the dedicated follow-up after memo auxiliary extraction.
- [x] 1.2 Map stats cache schema, rebuild, delta, and state-provider read ownership.

## 2. Implementation

- [x] 2.1 Add `StatsCacheDbPersistence` for stats schema, rebuild, memo snapshot, delta, and read primitives.
- [x] 2.2 Update `AppDatabase` lifecycle/rebuild/snapshot/delta helpers to delegate stats cache behavior.
- [x] 2.3 Update stats state providers to read through `AppDatabase` facade methods instead of direct stats-cache SQL.

## 3. Guardrails

- [x] 3.1 Add stats cache DB persistence to focused dependency guardrails.
- [x] 3.2 Guard against `AppDatabase` re-owning stats cache schema/rebuild/delta SQL.
- [x] 3.3 Guard against state providers re-owning stats cache table SQL.

## 4. Verification

- [x] 4.1 Run focused stats provider and DB migration tests.
- [x] 4.2 Run focused architecture guardrails.
- [x] 4.3 Run `flutter analyze`.
- [x] 4.4 Run broader regression if focused checks pass.
