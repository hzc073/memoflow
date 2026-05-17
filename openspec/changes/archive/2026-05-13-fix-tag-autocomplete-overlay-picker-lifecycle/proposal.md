# Change: Fix tag autocomplete overlay lifecycle around external pickers

## Why

GitHub issue #197 reports that when editing an existing memo on Android, the editor caret can start at the end of the memo. If the memo ends with a tag, tag autocomplete suggestions open automatically. When the user then opens the photo picker, the tag suggestion overlay remains visible instead of disappearing.

The current behavior is plausible because `TagAutocompleteOverlay` inserts an `OverlayEntry` into the root `Overlay`, while picker entry points do not explicitly end the text-editing/autocomplete interaction before launching an external picker.

## What Changes

- Define a shared lifecycle rule for memo compose tag autocomplete overlays.
- Make tag autocomplete overlays dismiss promptly when the owning editor focus is lost or when the owning autocomplete surface is no longer active.
- Treat external picker launch points, including Android gallery/photo picker, file picker, and camera capture, as boundaries that must leave tag autocomplete inactive before the platform/plugin UI opens.
- Add focused widget/state coverage for the overlay lifecycle and at least one compose surface that can reproduce the issue.

## Scope

In scope:

- `memos_flutter_app/lib/features/memos/tag_autocomplete.dart`
- `memos_flutter_app/lib/features/memos/memo_editor_screen.dart`
- Adjacent compose surfaces if needed for shared behavior:
  - `memos_flutter_app/lib/features/memos/note_input_sheet.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_inline_compose_card.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_inline_compose_coordinator.dart`
- Focused tests under `memos_flutter_app/test/features/memos` or `memos_flutter_app/test/state/memos`

Out of scope:

- API request/response models, route adapters, version compatibility logic, or files under `memos_flutter_app/lib/data/api` and `memos_flutter_app/test/data/api`.
- Changing tag suggestion ranking, matching syntax, or tag persistence.
- Reworking the memo editor opening selection behavior unless implementation finds it is necessary to close the picker overlay bug.

## Modularity

Active architecture phase: `evolve_modularity`.

This change is primarily feature UI lifecycle work inside `features/memos`. It should preserve current dependency directions and must not expand `state -> features`, `application -> features`, or `core -> higher-layer` allowlists.

Scoped modularity improvement:

- Keep root overlay ownership localized in the feature UI overlay component instead of duplicating ad hoc overlay teardown rules in every compose screen.
- Add focused lifecycle coverage so future compose surfaces cannot leave root `OverlayEntry` suggestions visible after focus loss or external picker launch.

## Validation

- Run `openspec validate fix-tag-autocomplete-overlay-picker-lifecycle --strict`.
- During implementation, run focused Flutter tests covering tag autocomplete lifecycle.
- Before PR, run `flutter analyze` and `flutter test` from `memos_flutter_app`.

