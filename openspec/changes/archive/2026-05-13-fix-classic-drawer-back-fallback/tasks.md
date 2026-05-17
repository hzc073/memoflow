# Tasks

- [x] 1. Add focused regression coverage
  - [x] 1.1 Add a widget test for standalone/classic `DraftBoxNavigationScreen` system back returning to `HomeEntryScreen`.
  - [x] 1.2 Add a widget test for standalone/classic `CollectionsScreen` system back returning to `HomeEntryScreen`.
  - [x] 1.3 Add or preserve coverage that embedded bottom navigation Draft Box/Collections back delegates to `HomeEmbeddedNavigationHost`.
- [x] 2. Implement scoped fallback behavior
  - [x] 2.1 Add standalone back handling for navigation-launched Draft Box without changing `DraftBoxScreen.show()` picker semantics.
  - [x] 2.2 Add standalone back handling for Collections while preserving local nested route pop behavior.
  - [x] 2.3 Route home fallback through `HomeEntryScreen` or equivalent entry seam, not direct `MemosListScreen`.
- [x] 3. Verify
  - [x] 3.1 Run focused Draft Box and Collections widget tests.
  - [x] 3.2 Run affected home navigation tests if touched.
  - [x] 3.3 Run `flutter analyze` if implementation touches app code.
