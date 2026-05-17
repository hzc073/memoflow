## 1. State Scoping

- [x] 1.1 Update `serverSettingsProvider` so it watches the active local-library state and remote account/API identity, and rebuilds when that identity changes.
- [x] 1.2 Add `autoDispose` or equivalent lifecycle cleanup so closed server settings pages do not retain stale administrative state.
- [x] 1.3 Update `ServerSettingsController` to receive the active `MemosApi` or scoped context at construction time instead of reading `memosApiProvider` during save operations.
- [x] 1.4 Ensure local-library mode or no remote account loads an unavailable server settings snapshot without sending server settings API requests.
- [x] 1.5 Preserve the existing successful attachment limit save behavior that invalidates `attachmentUploadSizeLimitResolverProvider`.

## 2. Regression Tests

- [x] 2.1 Add a focused settings/provider test harness that can simulate switching between two remote accounts while the server settings surface remains mounted.
- [x] 2.2 Add a regression test proving account A's server settings snapshot is discarded or reloaded after switching to account B.
- [x] 2.3 Add a regression test proving a save after switching accounts sends the update to the current account's server context, not the previous account.
- [x] 2.4 Add or update a local-library/no-account test proving server settings API requests are not sent without a remote account.
- [x] 2.5 Update existing `ServerSettingsController` test fakes if constructor scoping changes require it.

## 3. Verification and Boundary Review

- [x] 3.1 Run the focused settings tests that cover `ServerSettingsScreen` and `serverSettingsProvider`.
- [x] 3.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 3.3 Run `flutter test` from `memos_flutter_app`.
- [x] 3.4 Review touched files for modularity checklist items 4 and 7: server settings logic remains in state/data boundaries, and no new `state -> features`, `application -> features`, or `core -> higher-layer` imports are introduced.
