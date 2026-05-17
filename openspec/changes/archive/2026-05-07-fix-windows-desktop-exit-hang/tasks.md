## 1. Investigation / Baseline

- [x] 1.1 Confirm the affected Windows setting state: `windowsCloseToTray=true` versus `false` for the reported window `X` behavior.
- [x] 1.2 Reproduce on Windows release build from tray exit and window close, and record whether the process exits, hangs, or remains in Task Manager.
- [x] 1.3 Inspect the latest app logs and Windows Event Viewer around the failed exit to distinguish hang from crash.
- [x] 1.4 Add flushed Dart and native runner exit diagnostics for the remaining Windows shutdown sound investigation.
- [x] 1.5 Reproduce release window-close APPCRASH in `coremessaging.dll` after `CoUninitialize()` and capture native breadcrumbs.

## 2. Exit Lifecycle Fix

- [x] 2.1 Change Windows full-exit primary termination from `windowManager.destroy()` to a graceful close lifecycle after `setPreventClose(false)`.
- [x] 2.2 Keep direct process termination / destroy-like behavior only as the final timeout fallback.
- [x] 2.3 Keep fallback armed until all required cleanup and main-window termination steps finish or time out.
- [x] 2.4 Ensure repeated `requestExit()` calls remain idempotent and await the same in-flight exit.
- [x] 2.5 Ensure Windows runner Flutter/window objects are destroyed before `CoUninitialize()`.
- [x] 2.6 Avoid explicit `CoUninitialize()` on process exit when CoreMessaging/WebView teardown crashes after native shutdown completes.
- [x] 2.7 Use a final `ExitProcess(exit_code)` after graceful native shutdown to avoid crashing CRT/static teardown after `wWinMain` return.
- [x] 2.8 Use a final `TerminateProcess(GetCurrentProcess(), exit_code)` after graceful native shutdown when CoreMessaging still crashes during process detach.

## 3. Cleanup / Background Work

- [x] 3.1 Ensure full-exit startup cancels or ignores delayed WebDAV auto sync/backup scheduling.
- [x] 3.2 Ensure database close or owned write cleanup is bounded by timeout and cannot hang forever after fallback cancellation.
- [x] 3.3 Preserve close-to-tray behavior so enabled window close hides to tray without entering full exit.

## 4. Modularity / Guardrails

- [x] 4.1 Keep `DesktopExitCoordinator` as the single full-exit owner and avoid new `application -> features`, `state -> features`, or `core -> higher-layer` imports.
- [x] 4.2 Prefer injected cleanup callbacks or same-layer seams over feature imports for exit preparation.
- [x] 4.3 Update exit lifecycle tests so they fail if Windows primary termination regresses to `destroy` / direct `PostQuitMessage`.
- [x] 4.4 Add a native runner guardrail so desktop sub-window engines do not register WebView/CoreMessaging plugins.

## 5. Verification

- [x] 5.1 Run `flutter test test/application/desktop/desktop_exit_coordinator_test.dart` from `memos_flutter_app`.
- [x] 5.2 Run any focused sync/exit tests added for delayed WebDAV cancellation.
- [x] 5.3 Run `flutter analyze` and focused tests relevant to touched UI close entrypoints.
- [x] 5.4 Build and manually verify Windows release exit paths: tray exit, close-to-tray disabled window close, close-to-tray enabled window close.
