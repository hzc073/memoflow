## 1. Planning / UX Alignment

- [x] 1.1 Confirm the Pencil UI export `pencil_exports/l2Aqj.png` is the accepted visual reference for implementation.
- [x] 1.2 Decide exact entry gesture: tap embedded full-screen icon only, or also support drag/other affordances.
- [x] 1.3 Decide whether full-screen close returns with draft saved, matching current sheet close behavior.

## 2. Presentation State

- [x] 2.1 Add an internal compact/full-screen presentation state to `NoteInputSheet`.
- [x] 2.2 Ensure switching presentation modes keeps the same `MemoComposerController`, `FocusNode`, `TextEditingController`, attachment state, visibility state, draft state, and pending media state.
- [x] 2.3 Preserve focus and keyboard behavior when entering full-screen mode.

## 3. Compact Sheet UI

- [x] 3.1 Embed the expand control in the top sheet chrome/header area.
- [x] 3.2 Avoid floating/shadowed expand styling; make it read as part of the existing sheet UI.
- [x] 3.3 Keep existing compact editor, toolbar, visibility, send/voice, draft, attachment, linked memo, and location controls available.

## 4. Full-Screen UI

- [x] 4.1 Build the full-screen compose surface using existing `MemoFlowPalette` colors and current Material icon style.
- [x] 4.2 Remove the title text from the full-screen header.
- [x] 4.3 Place first-row toolbar actions in the header left area.
- [x] 4.4 Place collapse full-screen and close controls in the header right area.
- [x] 4.5 Place second-row tools directly below the header, with reduced vertical spacing.
- [x] 4.6 Move visibility and lightweight send controls to the right side of the second toolbar row.
- [x] 4.7 Maximize the multiline editor area below the toolbar section.
- [x] 4.8 Keep keyboard inset handling and safe-area behavior correct on mobile.

## 5. Behavior Preservation

- [x] 5.1 Verify text, cursor/selection, attachments, linked memos, location, visibility, and deferred media remain intact when toggling compact/full-screen.
- [x] 5.2 Verify full-screen send uses the same submit path as compact mode.
- [x] 5.3 Verify full-screen close uses the same draft-aware close behavior as compact mode.
- [x] 5.4 Verify collapse returns to compact mode without losing content.

## 6. Regression Coverage

- [x] 6.1 Add widget coverage for the compact expand button placement.
- [x] 6.2 Add widget coverage for entering and collapsing full-screen compose.
- [x] 6.3 Add widget coverage that content and visibility survive mode toggles.
- [x] 6.4 Add widget coverage that full-screen send calls the same submit behavior.
- [x] 6.5 Add layout-oriented assertions for no title text in full-screen mode and toolbar controls in the expected rows.

## 7. Verification

- [x] 7.1 Run focused Flutter tests for the affected note input sheet coverage.
- [x] 7.2 Run `flutter test test/features/memos` from `memos_flutter_app` if focused tests pass.
- [x] 7.3 Run `flutter analyze` from `memos_flutter_app`.
- [x] 7.4 Review imports and touched files for modularity guardrails.
