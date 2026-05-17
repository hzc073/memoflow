## Context

`NoteInputSheet` already owns the add-memo compose lifecycle:

- `MemoComposerController` stores the current text, pending attachments, linked memos, tag autocomplete state, and related compose actions.
- `noteDraftProvider` / compose draft repositories preserve draft behavior.
- `_buildComposeToolbar` assembles the toolbar actions from `MemoToolbarPreferences`.
- The bottom-sheet layout currently places the editor first and the toolbar/send controls near the bottom.

The new UI should be a presentation change over the same compose state, not a separate compose implementation.

## Target Layout

The accepted visual direction is:

```text
Compact bottom sheet
┌──────────────────────────────┐
│          handle        [⛶]   │  expand is embedded in sheet chrome
│                              │
│  visibility chip / content   │
│  editor                      │
│                              │
│  toolbar rows       send/rec │
└──────────────────────────────┘

Full-screen compose
┌──────────────────────────────┐
│ B I S code list       [⇱][×] │  first toolbar row reuses title space
│ # template attach ... [vis][send] │
├──────────────────────────────┤
│                              │
│  large multiline editor      │
│                              │
└──────────────────────────────┘
```

Important UI decisions from the Pencil exploration:

- The compact sheet expand control is part of the sheet header, not a floating bubble.
- The full-screen header has no `Create memo` title.
- The top-right close and collapse controls remain visible and grouped.
- The first toolbar row occupies the otherwise empty top-left header area.
- The second toolbar row is compact and directly adjacent to the first row.
- The send control in full-screen mode is lightweight and sits to the right of the visibility button, not as a large floating red button.
- The editor area starts immediately below the compact toolbar section.

## Behavior Model

Use one compose state machine with two presentation modes:

```text
NoteInputSheet
  mode: compact | fullscreen
  composer: MemoComposerController
  draft persistence: unchanged
  submit: unchanged
  close: draft-aware close
```

Transitions:

```text
compact --tap expand--> fullscreen
fullscreen --tap collapse--> compact
fullscreen --tap close--> close sheet with existing draft behavior
compact --tap outside/close--> close sheet with existing draft behavior
```

State preservation requirement:

- Text selection, focus target, current text, attachments, linked memos, location, visibility, pending deferred media, and tag autocomplete state should remain owned by the same `MemoComposerController` instance when switching modes.

## Implementation Direction

Prefer a small internal layout split inside `NoteInputSheet`:

```text
_NoteInputSheetState
  _presentationMode
  _buildCompactSheet(...)
  _buildFullscreenCompose(...)
  _buildCompactToolbar(...)
  _buildFullscreenToolbar(...)
```

If `_buildFullscreenToolbar` and the existing bottom toolbar start duplicating action construction, extract feature-local presentation helpers. Keep action construction backed by the existing `_buildComposeToolbar` action definitions or shared `MemoComposeToolbarActionSpec` list so behavior stays consistent.

Avoid moving compose state into new providers unless implementation proves the widget becomes unmanageable. This is a presentation mode change, not a new compose domain.

## Dependency Direction

The change should stay inside `features/memos` and existing state providers:

```text
features/memos/note_input_sheet.dart
  -> state/memos existing providers and controllers
  -> state/settings existing toolbar preferences
  -> core existing palette / markdown editing helpers
```

Do not introduce new reverse dependencies from `state`, `application`, or `core` into `features`.

## Risks / Trade-offs

- [Risk] Full-screen mode duplicates compose UI code and drifts from compact behavior. Mitigation: share toolbar action specs and keep one `MemoComposerController`.
- [Risk] Moving controls upward could reduce tap target clarity. Mitigation: keep controls at least Material `IconButton`-like hit sizes where practical, even if icon visuals are compact.
- [Risk] Keyboard insets may cover the editor in full-screen mode. Mitigation: full-screen layout should account for `MediaQuery.viewInsetsOf(context).bottom` and keep editor scrollable/expanded above the keyboard.
- [Risk] Existing attachment and deferred media UI can make the full-screen toolbar crowded. Mitigation: keep previews in the editor content stack/area as today, and leave overflow tools reachable through the existing toolbar horizontal scroll or more menu behavior.

## Non-Goals

- Do not change memo storage, sync, API, or upload semantics.
- Do not redesign `MemoEditorScreen` for existing memo editing in this change.
- Do not add commercial/private feature hooks.
- Do not remove the current quick bottom-sheet entry.
- Do not change default toolbar preferences.
