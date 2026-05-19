## 1. Native Menu Structure

- [x] 1.1 Install a macOS native menu with top-level menus `MemoFlow`, `Memo`, `Sync`, `AI`, `Tools`, `Window`, and `Help`.
- [x] 1.2 Replace the default Flutter editor-template menu at runtime with the approved MemoFlow menu structure.
- [x] 1.3 Preserve standard AppKit actions for About, Services, Hide, Quit, Minimize, Zoom, and Bring All to Front.

## 2. Menu Localization

- [x] 2.1 Keep English labels in `Base.lproj` as the fallback menu language.
- [x] 2.2 Add Simplified Chinese native menu localization for all approved menu and submenu labels.
- [x] 2.3 Verify Help Center and Memos Backend Docs labels are localized while preserving their approved URLs.

## 3. Native Command Bridge

- [x] 3.1 Add a focused macOS native command dispatcher for MemoFlow-specific menu item actions.
- [x] 3.2 Define stable command IDs for approved menu actions such as new memo, quick input, search memos, sync now, AI settings, help center, and backend docs.
- [x] 3.3 Ensure external help menu actions open `https://memoflow.hzc073.com/help/` and `https://usememos.com/docs`.

## 4. Dart Command Handling

- [x] 4.1 Add an application-owned Dart seam for handling macOS menu commands without importing feature screens into lower layers.
- [x] 4.2 Wire supported menu actions to existing MemoFlow workflows only.
- [x] 4.3 Omit or disable any approved menu item whose route cannot be reached safely in the first implementation pass.

## 5. Boundary and Verification

- [x] 5.1 Confirm the change does not touch API code, API tests, shared public models, or private/commercial Apple logic.
- [x] 5.2 Run a focused dependency search to verify no new lower-layer imports of feature screens are introduced.
- [x] 5.3 Build or inspect the macOS Debug app to verify the approved menu structure is present.
- [x] 5.4 Verify Simplified Chinese menu labels and English fallback behavior where locally possible.
- [x] 5.5 Document any verification commands that cannot be run locally and the residual risk.
