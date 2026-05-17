## Context

用户反馈两个关键现象：

- release 模式下退出软件会死机，并且会有 Windows 系统提示音。
- 窗口 `X` 也会触发同类声音；当窗口关闭路径进入 full exit 时，和 tray exit 共用 `DesktopExitCoordinator`。

当前代码路径中，tray exit 明确调用：

```
DesktopTrayController
  -> DesktopWindowManager.configureTrayActions()
  -> DesktopExitCoordinator.requestExit(reason: 'tray_exit')
```

主窗口关闭路径大致为：

```
window close / custom close button
  -> windowManager.close()
  -> window_manager emits close event
  -> DesktopExitCoordinator.onWindowClose()
  -> requestClose()
  -> hideToTray OR requestExit()
```

Windows full-exit 目前最终走到：

```
DesktopExitCoordinator._terminateMainWindowForExit()
  -> windowManager.destroy()
  -> window_manager Windows Destroy()
  -> PostQuitMessage(0)
```

本地 `window_manager 0.5.1` 的 Windows `destroy()` 并不销毁 HWND；它只是 `PostQuitMessage(0)`。这会让 native message loop 退出，但不会主动走 `WM_CLOSE` / `WM_DESTROY`。而 runner 中 `flutter_controller_` 的释放发生在 `FlutterWindow::OnDestroy()`：

```
WM_DESTROY
  -> FlutterWindow::OnDestroy()
  -> flutter_controller_ = nullptr
  -> Win32Window::OnDestroy()
  -> PostQuitMessage(0)
```

因此当前风险是：

```
PostQuitMessage(0)
  -> message loop exits
  -> CoUninitialize()
  -> stack object destruction later releases Flutter/WebView/plugin resources
```

对 WebView2 / COM / plugin teardown 来说，这个顺序不安全，符合 release exit hang/freezing 的症状。

## Goals / Non-Goals

**Goals:**

- Windows full exit 使用正常 native window lifecycle。
- tray exit、window close、storage/legal/update exit 等入口保持 idempotent，收敛到同一个 full-exit coordinator。
- close-to-tray 行为保持非破坏性：启用时 `X` 只隐藏窗口，不应 full exit。
- full exit 的 cleanup 有明确 timeout / fallback，不能在关闭窗口后无限挂起。
- 退出开始后避免继续调度新的 delayed WebDAV sync/backup。
- 用测试固定 lifecycle 语义，防止后续 performance optimization 再绕过 `WM_DESTROY`。

**Non-Goals:**

- 不重构 WebDAV 同步架构。
- 不改变数据库 schema、API compatibility、模型或商业/private hook。
- 不做跨平台退出策略大重写；本 change 聚焦 Windows desktop。

## Current Lifecycle Problem

当前 full-exit 顺序：

```
┌─────────────────────┐
│ requestExit()        │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│ close sub windows    │
├─────────────────────┤
│ unregister hotkey    │
├─────────────────────┤
│ dispose tray         │
├─────────────────────┤
│ setPreventClose(false)│
├─────────────────────┤
│ windowManager.destroy│  <-- primary path = PostQuitMessage(0)
├─────────────────────┤
│ delay 200ms          │  <-- fallback cancelled here
├─────────────────────┤
│ close databases      │  <-- can still hang after fallback cancellation
└─────────────────────┘
```

两个问题叠加：

1. `destroy()` bypasses graceful `WM_CLOSE` / `WM_DESTROY` lifecycle.
2. fallback cancellation happens before all cleanup is done.

## Proposed Lifecycle

建议 full-exit 主路径改成：

```
┌─────────────────────────────┐
│ requestExit()                │
│ _exiting = true              │
│ arm fallback                 │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│ prepare_for_exit             │
│ - cancel/ignore delayed sync │
│ - stop scheduling new work   │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│ close sub windows            │
├─────────────────────────────┤
│ unregister hotkey            │
├─────────────────────────────┤
│ dispose tray                 │
├─────────────────────────────┤
│ close databases / flush owned│
│ cleanup with timeout         │
├─────────────────────────────┤
│ setPreventClose(false)       │
├─────────────────────────────┤
│ windowManager.close()        │
│ -> WM_CLOSE / WM_DESTROY     │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│ native OnDestroy releases    │
│ Flutter controller before    │
│ CoUninitialize               │
└─────────────────────────────┘
```

Key design decision:

- `windowManager.close()` is the primary Windows full-exit termination action after `preventClose` is disabled.
- `windowManager.destroy()` / `exit(0)`-like behavior is only a last-resort fallback if graceful close does not complete in time.

## Additional Native Finding

After the graceful close lifecycle change, right-click tray exit still produced a Windows alert sound and Event Viewer reported `APPCRASH` in `coremessaging.dll`. The console showed two full `flutter_inappwebview_windows` teardown sequences, which indicates both the main Flutter engine and a desktop sub-window engine were registering WebView/CoreMessaging-backed plugins.

Quick input and settings sub-windows do not need `flutter_inappwebview_windows` or `webview_windows`. Registering those plugins in secondary engines creates extra CoreMessaging/WebView teardown work during exit and can crash even when the main window closes through `WM_CLOSE` / `WM_DESTROY`.

The native runner should therefore keep WebView plugins registered for the main engine through generated plugin registration, but exclude WebView plugins from `RegisterSubWindowPlugins`. A guardrail test should scan `windows/runner/flutter_window.cpp` so future sub-window plugin changes do not reintroduce WebView plugins into secondary engines.

## Close-to-Tray Split

Window close is not always full exit:

```
onWindowClose()
  ├─ windowsCloseToTray == true
  │    └─ hideToTray()
  └─ windowsCloseToTray == false
       └─ requestExit()
```

This split should remain explicit and covered by tests. The user-visible `X` behavior should not accidentally enter full-exit when close-to-tray is enabled.

## Background Work Gate

The log line:

```
[webdav] Request scheduled | kind=webDavSync reason=settings
```

means delayed WebDAV work can be scheduled near exit. It may not be the root cause, but it creates shutdown contention and can keep database/network resources active.

Preferred design:

- `DesktopExitCoordinator` exposes or owns an `isExiting` state.
- Sync scheduling receives an exit-preparation signal through an injected callback or a same-layer lifecycle seam.
- Delayed WebDAV timers are cancelled or ignored once full exit begins.
- Manual sync semantics outside exit remain unchanged.

Avoid adding new `application -> features` dependencies. If the coordinator needs cleanup hooks, prefer constructor-injected callbacks from `app.dart` / provider composition.

## Dependency Direction

Before:

```
features/home/desktop/windows_desktop_page_shell.dart
  -> package:window_manager
  -> native close event
  -> application/desktop/desktop_exit_coordinator.dart

application/desktop/desktop_exit_coordinator.dart
  -> state/settings/device_preferences_provider.dart
  -> state/system/logging_provider.dart
  -> data/db/database_registry.dart
  -> application/desktop/desktop_tray_controller.dart
  -> application/desktop/desktop_quick_input_controller.dart
```

After:

```
UI close entrypoints
  -> DesktopExitCoordinator.requestClose/requestExit
  -> injected cleanup seams / owned desktop services
  -> package:window_manager.close()
  -> native WM_CLOSE / WM_DESTROY
```

No new dependency should be introduced from `state`, `application`, or `core` into `features/*`. If `WindowsDesktopPageShell` is adjusted, it should either continue using the native close event path or call a coordinator seam without moving reusable business logic into the widget.

## Test Strategy

- Update `desktop_exit_coordinator_test.dart` so Windows primary termination action is `close`, not `destroy`.
- Add a guardrail that no Dart cleanup step required for graceful shutdown is ordered after the final process-termination signal.
- Add/adjust tests for:
  - close-to-tray enabled: close request hides to tray and does not full exit.
  - close-to-tray disabled: close request enters full exit.
  - repeated exit requests await the same in-flight exit.
  - fallback remains armed until cleanup and main-window close are both complete or timed out.
- Manual Windows release verification:
  - tray exit
  - custom titlebar `X`
  - native close event / Alt+F4 if available
  - close-to-tray enabled and disabled

## Risks / Unknowns

- The March 26 performance change may have been trying to avoid a previous `close()` hang. If reverting to `close()` reveals that older problem, the fallback must remain robust and observable.
- `DatabaseRegistry.closeAll()` may itself hang if there are active writes. The change should use bounded cleanup and leave diagnostics in logs.
- Sub-window engines may still be alive during main exit. Sub-window close timeouts should stay bounded.
- WebView2 / `flutter_inappwebview_windows` teardown may still emit debug dealloc logs from the main engine; duplicated teardown from sub-window engines is a risk signal and should not return.

## Exit Diagnostics

The remaining shutdown sound must be separated into three cases: a native crash, a force-exit fallback, or a normal process exit that only makes the Flutter debug tool report a device disconnect. Dart-side exit steps should therefore log `started`, `completed`, and `failed` breadcrumbs with elapsed timing and flush them before continuing. The Windows runner should also print `[native-exit]` breadcrumbs around `WM_DESTROY`, Flutter controller release, message-loop exit, and `CoUninitialize`, and mirror those breadcrumbs to `%TEMP%\MemoFlow_native_exit.log` because `flutter run` may stop streaming output as soon as the VM service disconnects.

Release diagnostics showed `APPCRASH` in `coremessaging.dll` with exception `0xc0000602` even after `flutter_controller_release_done`, `message_loop_exit`, and `co_uninitialize_done` were logged. The crash still occurred when explicit `CoUninitialize()` was skipped and when exiting through `ExitProcess()`, and it also reproduced with WebView and MediaKit registration isolated. That means Dart shutdown and primary native window teardown completed, but Windows process detach still touched CoreMessaging and crashed. The runner must keep Flutter/window objects in an inner scope so they are destroyed before process exit, then use a final `TerminateProcess(GetCurrentProcess(), exit_code)` after the graceful native shutdown breadcrumbs to bypass the crashing DLL detach path.
