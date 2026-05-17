## Why

Windows release builds can hang/freeze during full app exit and still produce a Windows system alert sound. The same symptom is observed from tray exit and from the window close path when it proceeds to a full exit.

Current investigation points at the Windows desktop exit lifecycle:

- `DesktopExitCoordinator` uses `windowManager.destroy()` as the primary Windows main-window termination step.
- In `window_manager 0.5.1`, Windows `destroy()` only calls `PostQuitMessage(0)`, which bypasses the normal `WM_CLOSE` / `WM_DESTROY` window teardown path.
- The app runner only releases `flutter_controller_` in `FlutterWindow::OnDestroy()`, so bypassing `WM_DESTROY` risks tearing down COM/WebView/plugin resources after `CoUninitialize()`.
- The exit fallback is cancelled before `close_databases`, so a later cleanup step can still hang without a process-level timeout.
- Logs show WebDAV work can still be scheduled near exit, which may increase shutdown contention even if it is not the root cause.

This change should make Windows full exit graceful, bounded, and observable.

## What Changes

- Replace the primary Windows full-exit termination path with the normal native close lifecycle (`WM_CLOSE` -> `WM_DESTROY`) after disabling `preventClose`.
- Reserve direct process termination / `destroy`-like behavior for a last-resort timeout fallback, not the main path.
- Keep the exit operation idempotent so tray exit, window close, update restart/exit flows, and storage/legal error exits converge on one coordinator.
- Keep the force-exit fallback armed until all required cleanup either completes or times out.
- Prevent exit-time background work from scheduling new WebDAV sync/backup runs after the app has begun full exit.
- Add tests/guardrails for Windows exit step ordering, termination semantics, and the close-to-tray/full-exit split.

## Non-Goals

- Do not redesign WebDAV sync, backup, or settings persistence.
- Do not change API routes, request/response models, database schemas, or version compatibility logic.
- Do not add private/commercial hooks or paid-feature state.
- Do not rewrite the Windows runner beyond the minimal lifecycle fix needed for graceful shutdown.

## Capabilities

### New Capabilities

- `windows-desktop-exit-lifecycle`: Defines Windows desktop full-exit and close-to-tray lifecycle behavior.

### Modified Capabilities

- None.

## Impact

- Likely touched runtime files:
  - `memos_flutter_app/lib/application/desktop/desktop_exit_coordinator.dart`
  - `memos_flutter_app/lib/application/desktop/desktop_tray_controller.dart` if fallback behavior needs alignment
  - `memos_flutter_app/lib/features/home/desktop/windows_desktop_page_shell.dart` if the custom close button should call the coordinator directly
  - `memos_flutter_app/lib/application/sync/sync_coordinator.dart` or an injected exit-preparation seam if delayed sync scheduling needs cancellation
  - `memos_flutter_app/windows/runner/flutter_window.cpp` / `main.cpp` only if Dart-side lifecycle fixes are insufficient
- Likely touched tests:
  - `memos_flutter_app/test/application/desktop/desktop_exit_coordinator_test.dart`
  - New or existing focused tests for close-to-tray versus full-exit routing
- Manual verification:
  - Windows release build: tray exit, titlebar/window close with close-to-tray disabled, titlebar/window close with close-to-tray enabled.

## Architecture / Modularity

- Architecture phase: `evolve_modularity`.
- Touched checklist items:
  - `5.` `app.dart` and `main.dart` primarily act as composition roots.
  - `7.` Touched write paths have clear owners such as services, repositories, or mutation seams.
  - `8.` Architecture guardrail tests protect high-risk dependency directions.
  - `10.` Every change touching a coupled area leaves that area equal or better structured than before.
- Scoped modularity improvement:
  - Keep `DesktopExitCoordinator` as the single full-exit owner and add/adjust guardrail tests so future optimizations cannot silently replace graceful Windows lifecycle with direct `PostQuitMessage`.
  - Prefer injected exit-preparation callbacks from the composition root over adding new `application -> features` dependencies.
