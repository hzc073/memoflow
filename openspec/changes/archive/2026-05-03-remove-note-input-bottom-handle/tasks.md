## 1. Implementation

- [x] 1.1 Remove the bottom legacy `Padding -> Container(width: 130, height: 6)` block from `memos_flutter_app/lib/features/memos/note_input_sheet.dart`.
- [x] 1.2 Preserve the top `40x6` drag handle and existing compose toolbar/editor behavior.
- [x] 1.3 Keep the change local to `NoteInputSheet`; do not add imports, providers, route changes, platform branches, API changes, or new shared state.

## 2. Verification

- [x] 2.1 Review the affected widget tree and confirm `NoteInputSheet` now renders only the intentional top handle.
- [x] 2.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 2.3 Verify on Android device/emulator when available: tap `+`, wait for the keyboard, and confirm no extra horizontal bar appears above the input method.
- [x] 2.4 Confirm the diff introduces no new `state -> features`, `application -> features`, or `core -> state|application|features` dependency.
