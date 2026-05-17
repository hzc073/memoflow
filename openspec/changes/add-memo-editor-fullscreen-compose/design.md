## Context

Current memo editing has three overlapping presentation shapes:

```text
MemoEditorScreen(page)
  AppBar
    title
    Save action
  body
    editor
    compose toolbar
    bottom circular Save action

MemoEditorScreen(desktopModal / desktopFullscreen)
  desktop header
    title
    Save action
    fullscreen / restore action
    close action
  body
    editor
    compose toolbar
    bottom circular Save action

NoteInputSheet(fullscreen)
  shared-looking fullscreen writing layout
    top chrome: close + collapse
    body: attachments/chips/location/editor
    bottom toolbar: formatting/actions + visibility + send/voice
```

The UI duplication problem is narrow, but the implementation should avoid creating a second copy of the note-input full-screen layout inside the already large `MemoEditorScreen`.

## Goals / Non-Goals

**Goals:**

- Mobile normal-page memo editor top-right action opens full-screen compose mode.
- Full-screen editor mode preserves the same controller, focus node, draft identity, attachments, linked memos, location, visibility, toolbar preferences, tag autocomplete, and save path.
- Full-screen editor uses save/check as its primary action.
- Full-screen editor close uses the existing draft-aware close behavior.
- Full-screen editor collapse only restores the normal editor layout.
- Desktop and embedded editor chrome do not expose duplicate header save actions when bottom save is visible.
- Note input full-screen behavior remains equivalent after sharing presentation structure.

**Non-Goals:**

- No new editor route for mobile full-screen.
- No save behavior rewrite.
- No API or persistence contract change.
- No desktop window behavior redesign beyond duplicate save cleanup.

## Proposed Shape

### 1. Create a shared full-screen compose presentation seam

Preferred shape:

```text
features/memos/widgets/memo_compose_fullscreen_surface.dart
  MemoComposeFullscreenSurface
    - top chrome: close + collapse
    - attachment/metadata slot
    - editor slot
    - bottom toolbar rows
    - visibility control slot/config
    - primary action slot/config

features/memos/widgets/note_input_fullscreen_compose.dart
  NoteInputFullscreenCompose
    -> adapter around MemoComposeFullscreenSurface
    -> primary action: send/voice

features/memos/memo_editor_screen.dart
  _buildFullscreenEditorCompose(...)
    -> adapter around MemoComposeFullscreenSurface
    -> primary action: save/check
```

The shared widget should stay presentation-only. It should receive render state, slots, and callbacks. It must not own draft persistence, submit/save orchestration, attachment staging, sync, or mutation behavior.

### 2. Add local full-screen mode to the mobile page editor

The mobile normal page should switch layouts inside the same `MemoEditorScreen` state:

```text
normal page editor
  tap AppBar fullscreen
        |
        v
same MemoEditorScreen state
  _editorPresentationMode = fullscreenCompose
        |
        +-- collapse -> normal page editor
        +-- close    -> _requestCloseEditor()
        +-- save     -> _save()
```

This keeps the same `TextEditingController`, `FocusNode`, `MemoComposerController`, pending attachments, relation state, and draft timers alive.

### 3. Keep primary-action semantics separate

The full-screen surface should not decide whether the primary action means save, send, or voice. That belongs to each adapter:

```text
NoteInputFullscreenCompose
  empty draft, no attachments -> voice icon/action
  text or attachments         -> send icon/action

MemoEditor fullscreen
  always save/check action
  saving                      -> progress indicator
```

This prevents editor UI from accidentally showing `Create memo`, send, or voice semantics.

### 4. Clean up duplicate save UI

The memo editor bottom circular save button remains the primary visible save action. Header save actions should be removed where they duplicate it:

```text
mobile page normal mode:
  AppBar right: fullscreen entry
  bottom right: save

mobile page fullscreen mode:
  top chrome: close + collapse
  bottom right: save

desktop modal:
  header right: fullscreen + close
  bottom right: save

desktop fullscreen:
  header/top chrome: restore + close
  bottom right: save

embedded pane:
  header right: close
  bottom right: save
```

Keyboard save shortcuts such as Ctrl/Cmd+Enter should remain unchanged.

### 5. Focus and keyboard behavior

When entering full-screen editor mode:

- If the editor focus node is already focused, reset focus before switching layout to avoid keeping the old text input client.
- After the frame, request focus for the full-screen editor.
- Collapse should restore normal layout and request focus again when appropriate.

This mirrors the note input full-screen focus behavior and avoids Android keyboard/client confusion.

## Dependency Direction / Modularity

Current phase is `evolve_modularity`. This change touches feature presentation code, including large compose/editor widgets. It should improve the touched area by extracting a feature-local presentation seam:

```text
features/memos/memo_editor_screen.dart
features/memos/widgets/note_input_fullscreen_compose.dart
        |
        v
features/memos/widgets/memo_compose_fullscreen_surface.dart
```

No lower layer should import the new shared presentation widget:

```text
state/application/core  -X->  features/memos/widgets/memo_compose_fullscreen_surface.dart
```

Save/write behavior remains owned by existing editor controller/provider paths:

```text
MemoEditorScreen UI callback
  -> _save()
  -> memoEditorControllerProvider.saveMemo(...)
  -> existing sync request path
```

The shared surface should only call callbacks.

## Risks / Trade-offs

- [Risk] The shared surface becomes too generic and hard to read. Mitigation: keep it focused on the existing full-screen compose shape, with slots only for differences that already exist between note input and editor.
- [Risk] Editor accidentally inherits note-input send/voice strings or icons. Mitigation: use adapter-owned primary action widgets/configs and add tests for editor save icon/tooltip.
- [Risk] Mobile full-screen mode loses draft or attachment state. Mitigation: keep full-screen as local presentation state within the same `MemoEditorScreen` instance and test text/metadata preservation.
- [Risk] Desktop users lose an expected save affordance. Mitigation: retain the bottom save action and keyboard shortcuts; only remove duplicate header save when another save UI remains visible.
- [Risk] Refactoring note input full-screen changes layout or focus behavior. Mitigation: keep existing note input full-screen widget tests and add regression coverage around existing keys/toolbar layout.

## Resolved Decisions

- The full-screen editor save button should use the compact full-screen primary action treatment in the shared bottom toolbar, while keeping save/check iconography and `Save` tooltip semantics.
- Embedded-pane header save should be removed together with desktop header save because it duplicates the bottom save button and uses the same `MemoEditorScreen` chrome path.
