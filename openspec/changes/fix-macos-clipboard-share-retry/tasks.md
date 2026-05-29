## 1. Preparation

- [x] 1.1 Confirm active architecture phase is still `evolve_modularity` from `openspec/config.yaml`.
- [x] 1.2 Confirm the fix does not require API-related files. If `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api` appears necessary, pause for explicit approval.
- [x] 1.3 Read current clipboard/share lifecycle code before editing: `memos_flutter_app/lib/app.dart`, `memos_flutter_app/lib/application/startup/startup_coordinator.dart`, `memos_flutter_app/lib/application/startup/startup_coordinator_share.dart`, and `memos_flutter_app/lib/application/startup/startup_coordinator_state.dart`.
- [x] 1.4 Read current desktop share task IPC code before editing: `memos_flutter_app/lib/features/share/desktop_share_task_window_app.dart`, `memos_flutter_app/lib/application/desktop/desktop_window_manager.dart`, and `memos_flutter_app/lib/application/desktop/desktop_share_window.dart`.

## 2. Share Flow Release Seam

- [x] 2.1 Add a narrow callback or equivalent seam owned by `StartupCoordinator` that fires when share-flow ownership is fully released and no active desktop share task remains.
- [x] 2.2 Wire `App` to that seam so release events schedule a bounded clipboard check burst with a diagnostic source such as `share_flow_released`.
- [x] 2.3 Ensure same-URL duplicate suppression remains URL-based so an unchanged clipboard value does not prompt again after a failed or canceled flow.
- [x] 2.4 Ensure active share flows and active desktop share tasks still suppress clipboard checks until the release seam fires.

## 3. Desktop Share Task Cleanup

- [x] 3.1 Review result handling for desktop share task windows and ensure successful result handoff removes the request id before release notification.
- [x] 3.2 Review cancellation handling for desktop share task windows and ensure cancellation removes the request id before release notification.
- [x] 3.3 Ensure unknown or invalid desktop share task request ids remain ignored and do not release unrelated active share tasks.
- [x] 3.4 Ensure multiple active desktop share tasks keep global share-flow suppression active until the last task completes or cancels.

## 4. Modularity And Guardrails

- [x] 4.1 Keep clipboard retry scheduling out of share UI widgets; `ShareClipScreen` and desktop share task window UI should not directly read the clipboard or own global retry policy.
- [x] 4.2 Keep API files untouched; no request/response model, route adapter, or API compatibility change is part of this fix.
- [x] 4.3 Add or update focused tests that lock the callback seam and prevent future regressions in share-flow release retry behavior.

## 5. Tests

- [x] 5.1 Add a test that simulates URL A being prompted, share flow releasing, clipboard changing to URL B, and URL B becoming eligible for a new prompt without app resume.
- [x] 5.2 Add a test that verifies the same URL is not prompted again after share-flow release.
- [x] 5.3 Add a test that verifies clipboard checks are skipped while share flow or desktop share task state is active.
- [x] 5.4 Add or update desktop share task tests for result cleanup, cancellation cleanup, unknown request id handling, and multiple active task behavior.
- [x] 5.5 Run focused startup/share tests covering the changed files.

## 6. Verification

- [x] 6.1 Run `flutter analyze` from `memos_flutter_app`.
- [x] 6.2 Run focused share/startup/desktop window tests from `memos_flutter_app`.
- [x] 6.3 Run `openspec validate fix-macos-clipboard-share-retry --strict`.
- [x] 6.4 Run `git diff --check`.

## 7. Manual Smoke

- [ ] 7.1 On macOS, copy supported URL A, confirm clipping, force or observe a clipping failure/cancellation, then copy supported URL B while the app remains foregrounded; confirm the app prompts for URL B.
- [ ] 7.2 On macOS, repeat 7.1 without changing the clipboard after failure/cancellation; confirm the app does not repeatedly prompt for URL A.
- [ ] 7.3 On macOS, leave an active share task window open and copy URL B; confirm the app does not interrupt the active share task with a second prompt.
- [ ] 7.4 On macOS, complete or cancel the active share task window, then copy URL B; confirm a new prompt can appear after the task releases.
