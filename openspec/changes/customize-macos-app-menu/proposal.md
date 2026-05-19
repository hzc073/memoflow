## Why

The checked-in macOS shell still uses the default Flutter menu structure, including editor-oriented items that do not match MemoFlow's workflows. MemoFlow needs a macOS menu that feels native, uses system-language localization with English fallback, and exposes a curated set of MemoFlow actions.

## What Changes

- Replace the default top-level menu set with `MemoFlow`, `Memo`, `Sync`, `AI`, `Tools`, `Window`, and `Help`.
- Localize menu titles through native macOS localization so Simplified Chinese users see Chinese labels and English remains the fallback.
- Keep required macOS application/window behavior such as Services, Hide, Quit, Minimize, Zoom, and Bring All to Front.
- Add MemoFlow-specific menu items for memo, sync, AI, tools, window, and help workflows.
- Define native-to-Flutter dispatch for application-specific actions that cannot be handled by AppKit selectors alone.
- Add external help links:
  - Help Center: `https://memoflow.hzc073.com/help/`
  - Memos Backend Docs: `https://usememos.com/docs`
- Preserve the `evolve_modularity` architecture phase. This change touches macOS platform shell code and should use a narrow platform bridge instead of adding reverse dependencies from lower layers into feature screens.

## Capabilities

### New Capabilities

- `macos-app-menu`: Rules for the macOS top-level menu structure, localized labels, native system actions, MemoFlow-specific actions, and help/documentation links.

### Modified Capabilities

- None.

## Impact

- Affected areas:
  - `memos_flutter_app/macos/Runner/AppDelegate.swift`
  - `memos_flutter_app/macos/Runner/MainFlutterWindow.swift`
  - macOS localized menu resource files such as `zh-Hans.lproj/MainMenu.strings`
  - macOS native entry points such as `AppDelegate.swift` or a focused menu action bridge
  - Dart desktop/menu dispatch code for MemoFlow-specific actions
- No API route, API model, or API compatibility behavior changes.
- No StoreKit, subscription, entitlement, receipt, pricing, signing secret, notarization, TestFlight, App Store, or private release automation behavior is introduced.
- Modularity impact: implementation should avoid making `core`, `application`, or `state` depend upward on `features`; menu commands should flow through an explicit desktop/menu seam owned by the application shell.
