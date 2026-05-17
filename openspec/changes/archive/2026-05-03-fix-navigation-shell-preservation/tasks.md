## 1. Scope Confirmation

- [x] 1.1 Reproduce the reported Tags `More` -> back behavior in bottom navigation mode and record the failing route sequence.
- [x] 1.2 Audit current `pushAndRemoveUntil(... MemosListScreen ...)` call sites and classify each as confirmed repro, potential shell risk, or intentionally standalone.
- [x] 1.3 Confirm no API, data model, sync, private extension, or commercial-hook files are needed for this navigation-only change.

## 2. Shell-Aware Drawer Routes

- [x] 2.1 Add `presentation` and `embeddedNavigationHost` support to `TagsScreen` following the existing `SettingsScreen` / `ResourcesScreen` pattern.
- [x] 2.2 Update `TagsScreen` back, drawer destination, tag selection, and notifications actions to delegate to `HomeEmbeddedNavigationHost` when present.
- [x] 2.3 Replace `TagsScreen` standalone home fallback with a `HomeEntryScreen` path or equivalent entry seam that respects configured navigation mode.
- [x] 2.4 Add `presentation` and `embeddedNavigationHost` support to `AboutScreen`.
- [x] 2.5 Update `AboutScreen` back, drawer destination, tag selection, and notifications actions to delegate to `HomeEmbeddedNavigationHost` when present.
- [x] 2.6 Replace `AboutScreen` standalone home fallback with a `HomeEntryScreen` path or equivalent entry seam that respects configured navigation mode.
- [x] 2.7 Keep shell tag selections inside the bottom navigation body instead of pushing a standalone tagged memo route over the shell.

## 3. Destination Builder Propagation

- [x] 3.1 Update `buildDrawerDestinationScreen` so `AppDrawerDestination.tags` receives `presentation` and `navigationHost`.
- [x] 3.2 Update `buildDrawerDestinationScreen` so `AppDrawerDestination.about` receives `presentation` and `navigationHost`.
- [x] 3.3 Review `recycleBin`, `syncQueue`, and `stats` drawer destinations and either add host-aware constructor support or document why their existing pop-first behavior is safe.
- [x] 3.4 Ensure any added constructor support preserves existing desktop rail, expanded sidebar, and overlay panel behavior.

## 4. Fallback Route Cleanup

- [x] 4.1 Replace confirmed unsafe home-reset fallbacks from bare `MemosListScreen` to `HomeEntryScreen` without changing local pop behavior.
- [x] 4.2 Review `MemoDetailScreen` archived restore and decide whether to fix in this change or leave a documented follow-up based on available host context and testability.
- [x] 4.3 Review reminder/startup direct launch fallbacks and avoid broad behavior changes unless focused tests prove the shell preservation contract applies.
- [x] 4.4 Keep all changes inside `memos_flutter_app` runtime/tests unless OpenSpec or test artifacts require otherwise.

## 5. Regression Tests

- [x] 5.1 Add a `HomeBottomNavShell` widget test covering Tags opened from the shell and back preserving the bottom navigation shell.
- [x] 5.2 Add a `HomeBottomNavShell` widget test covering About opened from the shell and back preserving the bottom navigation shell.
- [x] 5.3 Add standalone fallback tests proving Tags and About return through `HomeEntryScreen` and respect bottom navigation preferences.
- [x] 5.4 Add or tighten a guardrail test that fails when a drawer destination opened through the shell lacks host context.
- [x] 5.5 Preserve existing notifications/settings back-safety tests and ensure they still pass.
- [x] 5.6 Add regression coverage proving shell tag selection keeps the bottom bar visible and system back clears only the active tag filter first.

## 6. Verification

- [x] 6.1 Run focused navigation tests in `memos_flutter_app` for home shell, tags/about, settings, and notifications.
- [x] 6.2 Run changed-file analysis for the navigation/runtime/test files touched by this change.
- [x] 6.3 Run focused widget tests for home shell navigation, notifications, and AI summary overlay back-safety.
- [x] 6.4 Summarize any intentionally deferred fallback risks, especially memo detail restore or startup launch paths, before handing off.
- [x] 6.5 Run focused shell tag tests and changed-file analysis after the follow-up tag-route fix.
