## Context

The current macOS menu is the default Flutter template menu. It contains broad text-editor commands such as spelling, substitutions, transformations, and speech, while MemoFlow-specific workflows such as quick input, sync, AI, import/export, and help links are absent.

The menu is owned by the macOS platform shell, but most MemoFlow-specific actions live in Flutter. Native menu items therefore need two implementation paths:

- AppKit selectors for standard system actions.
- A narrow native-to-Dart command bridge for MemoFlow-specific actions.

The app is currently in the `evolve_modularity` phase. This change touches platform shell code and application command routing; it must avoid adding lower-layer dependencies on feature screens.

## Goals / Non-Goals

**Goals:**
- Replace the default menu with the approved top-level structure: `MemoFlow`, `Memo`, `Sync`, `AI`, `Tools`, `Window`, and `Help`.
- Provide Simplified Chinese menu localization through native macOS resources, with English as the `Base.lproj` fallback.
- Keep native system actions wired through AppKit where possible.
- Route MemoFlow-specific menu actions through an explicit command seam before reaching UI/navigation behavior.
- Open Help Center and Memos Backend Docs as external URLs.

**Non-Goals:**
- Do not make native menu labels follow the app's in-app language setting in this change.
- Do not add commercial Apple behavior, StoreKit, entitlement, receipt, pricing, signing, or release automation.
- Do not implement new product features behind menu items; menu items should only expose existing workflows.
- Do not change API compatibility or data models.

## Decisions

1. **Use native localization files for menu text**
   `Base.lproj/MainMenu.xib` remains the English fallback. Chinese labels should be supplied through `zh-Hans.lproj/MainMenu.strings`.

   Alternatives considered:
   - Dynamically update menu titles from Flutter preferences: rejected for this change because it requires a bidirectional language bridge and creates more runtime state coupling.
   - Hardcode Chinese labels in the XIB: rejected because it removes English fallback and breaks non-Chinese system behavior.

2. **Remove the default `Edit` top-level menu**
   The approved menu structure intentionally omits `Edit`. This keeps the menu focused on MemoFlow workflows and avoids carrying default template items that the user does not want.

   Alternatives considered:
   - Keep a trimmed `Edit` menu: rejected by the agreed top-level structure.
   - Move edit actions under `Memo`: rejected because standard text editing commands do not map cleanly to MemoFlow domain actions.

3. **Split actions by ownership**
   System actions such as Services, Hide, Quit, Minimize, Zoom, and Bring All to Front should continue to use AppKit selectors. MemoFlow actions such as New Memo, Quick Input, Sync Now, AI Settings, and Help Center should dispatch through a single native menu command channel.

   Alternatives considered:
   - Wire each menu item directly to feature-specific Dart code: rejected because it encourages feature coupling.
   - Implement app-specific actions entirely in Swift: rejected because the relevant app state and navigation live in Flutter.

4. **Use a command registry/seam on the Dart side**
   Dart handling should centralize macOS menu commands in an application/desktop-owned seam, then delegate to existing services, providers, or navigation hooks. This keeps dependency direction explicit and prevents platform shell code from importing feature screens directly.

   Alternatives considered:
   - Add menu command handling directly in `app.dart`: acceptable for initial wiring only if it remains a composition root; longer-lived command mapping should be extracted if it grows.

## Risks / Trade-offs

- [Menu item has no valid runtime target] -> Disable or omit the item until the corresponding existing workflow can be reached without brittle navigation.
- [Native menu localization drifts from Flutter strings] -> Keep menu-specific strings small and review them with each menu change.
- [Command bridge becomes a feature dependency shortcut] -> Keep command IDs stable and route through an application-owned seam rather than importing screens from lower layers.
- [Removing `Edit` surprises text-field users] -> Reassess after testing; AppKit editing shortcuts may still work through responders even without a visible top-level `Edit` menu, but the menu will no longer advertise those commands.

## Migration Plan

1. Install the approved menu structure from the macOS native app delegate at launch, replacing the default Flutter template menu.
2. Add native Simplified Chinese localization for menu titles.
3. Add a focused native menu command bridge for non-AppKit menu actions.
4. Add Dart-side handling for the first supported action set, using existing workflows only.
5. Verify the macOS Debug build, menu labels, external help links, and command dispatch.

Rollback strategy:
- Restore the previous XIB and remove the menu command bridge if menu dispatch causes runtime instability.
- No data migration is required.

## Open Questions

- Should unsupported menu actions be omitted initially, or shown disabled until their route is connected?
- Should `Settings...` in the `MemoFlow` menu open the existing desktop settings window or the in-app settings page when no desktop settings window is available?
