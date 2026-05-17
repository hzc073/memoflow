## 1. Preference and Sidebar Entry

- [x] 1.1 Add `showDrawerDraftBox` to `WorkspacePreferences` defaults, constructor, JSON serialization/parsing, `copyWith`, and legacy compatibility conversion.
- [x] 1.2 Add `showDrawerDraftBox` to legacy `AppPreferences` compatibility fields, JSON serialization/parsing, and `copyWith` only as needed for split preference bridging.
- [x] 1.3 Add `WorkspacePreferencesController.setShowDrawerDraftBox(bool)` and wire persistence through the existing workspace preference owner.
- [x] 1.4 Add Draft Box to `CustomizeDrawerScreen` with default enabled behavior and localized Draft Box label.
- [x] 1.5 Add Draft Box to `AppDrawerDestination` and render it in both AppDrawer model-driven destinations and legacy/manual sidebar button paths, gated by `showDrawerDraftBox`.

## 2. Home Navigation Destination

- [x] 2.1 Add `HomeRootDestination.draftBox` without changing default `HomeNavigationPreferences`.
- [x] 2.2 Register Draft Box in `home_navigation_resolver.dart` picker and fallback logic so it is selectable, deduplicated, and available in local/server workspaces.
- [x] 2.3 Register Draft Box in `home_root_destination_registry.dart` with icon, localized label, drawer mapping, and screen construction.
- [x] 2.4 Update `buildDrawerDestinationScreen` and shell drawer handling paths so `AppDrawerDestination.draftBox` routes through the same home navigation seams as other destinations.
- [x] 2.5 Ensure `HomeBottomNavShell` can display and switch to Draft Box while preserving the shell and center create FAB behavior.

## 3. Draft Selection to Editor Flow

- [x] 3.1 Add an optional selected-draft launch parameter to `NoteInputSheet.show(...)` and `NoteInputSheet`, keeping existing callers source-compatible.
- [x] 3.2 Restore `initialDraftUid` inside `NoteInputSheet` through the existing `_restoreComposeDraft` / `NoteInputDraftSessionHelper` path, including non-text metadata and active draft id.
- [x] 3.3 Treat missing or deleted selected drafts as a non-fatal empty compose launch.
- [x] 3.4 Add a navigation destination wrapper/helper for Draft Box that awaits `DraftBoxScreen.show(...)` and opens `NoteInputSheet` with the returned draft id.
- [x] 3.5 Preserve existing compose-toolbar and inline-compose Draft Box picker behavior unchanged.
- [x] 3.6 Refresh navigation-launched Draft Box after note input closes and version draft card markdown cache keys so same-uid edited drafts display latest content immediately.

## 4. Tests and Guardrails

- [x] 4.1 Add/update preference model tests for `showDrawerDraftBox` defaults, JSON round trip, absent-key migration default, and legacy split preference bridging.
- [x] 4.2 Add/update drawer widget tests verifying Draft Box appears by default, hides when disabled, and can be re-enabled from Customize Sidebar.
- [x] 4.3 Add/update bottom navigation resolver/settings/registry tests verifying Draft Box appears in the picker, is not a default slot, and has label/icon metadata.
- [x] 4.4 Add/update Draft Box navigation tests verifying a navigation-launched draft selection opens `NoteInputSheet` with the selected draft id and keeps the bottom navigation shell mounted when applicable.
- [x] 4.5 Add/update note input tests verifying `initialDraftUid` restores content and supported draft metadata, and missing draft ids do not crash.
- [x] 4.6 Run architecture guardrail tests covering navigation/draft changes, or add focused guardrail coverage if an existing test does not cover the touched dependency direction.
- [x] 4.7 Add regression coverage for same-uid draft card refresh and navigation-launched edit close showing the latest draft content.

## 5. Verification

- [x] 5.1 Run focused tests for preferences, drawer customization, home navigation, Draft Box, and note input draft restore.
- [x] 5.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 5.3 Run `flutter test` from `memos_flutter_app`, or document any environment blocker.
- [x] 5.4 Confirm no files under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api` were changed.
