## Context

GitHub issue `#199` reports that Android users lose the system keyboard after switching away from the app while creating or editing a memo, then returning. The relevant memo editing surfaces currently own focus locally:

- `NoteInputSheet` owns `_editorFocusNode` for compact add-memo compose and passes the same focus node into full-screen compose.
- `MemoEditorScreen` owns `_editorFocusNode` for editing existing memos or editing drafts.
- `MemosListScreen` owns `_inlineComposeFocusNode` for the home inline compose editor.

These surfaces request focus on initial open or after explicit layout transitions, but none of them currently observes Android app lifecycle transitions to restore the platform IME after resume. Flutter focus can remain on the editor while Android has already hidden the IME, so `autofocus` and a no-op `requestFocus()` are not enough after background/resume.

The project is in `evolve_modularity` with a modularity score of `4/10`. This change should improve checklist item `4.` by extracting shared Android keyboard-resume policy out of individual screen bodies, and must not worsen items `1.`, `2.`, or `3.` by adding lower-layer dependencies on feature UI.

## Goals / Non-Goals

**Goals:**

- Restore the Android system keyboard when a memo editing surface had focus and the keyboard was visible before app backgrounding.
- Cover `NoteInputSheet` compact compose, `NoteInputSheet` full-screen compose, `MemoEditorScreen`, and home inline compose.
- Avoid restoring keyboard for unrelated text inputs or editors that were not actively using the keyboard.
- Keep the behavior feature-scoped rather than global in `app.dart`.
- Extract reusable lifecycle/IME restoration policy into a feature-local helper or controller with injectable decisions/callbacks for focused tests.

**Non-Goals:**

- No changes to memo create/update APIs, sync behavior, drafts persistence, attachments, location, visibility, or toolbar behavior.
- No new package dependency such as a keyboard visibility plugin.
- No attempt to keep the Android IME visible while the app is backgrounded. The goal is to restore it after resume when appropriate.
- No Windows, iOS, macOS, Linux, or web behavior change.

## Decisions

### Decision: Use a feature-local keyboard resume helper

Create a helper such as `AndroidMemoKeyboardResumeController` under `features/memos` that owns the shared lifecycle policy. Each editing surface wires in:

- the editor `FocusNode`
- a `BuildContext` or route-current predicate
- an `isSurfaceEligible` callback
- a keyboard-visible predicate based on `MediaQuery.viewInsetsOf(context).bottom > 0`
- a keyboard show callback, defaulting to the Flutter text input channel

Before:

```text
NoteInputSheet       -> local focus behavior only
MemoEditorScreen     -> local focus behavior only
MemosListScreen      -> local focus behavior only
```

After:

```text
NoteInputSheet       -> feature helper
MemoEditorScreen     -> feature helper
MemosListScreen      -> feature helper
feature helper       -> Flutter focus/text input primitives
```

This keeps dependency direction inside the feature layer and avoids new `state -> features`, `application -> features`, or `core -> features` imports.

Alternative considered: add one global observer in `app.dart`. Rejected because the global app layer cannot safely know whether the active text input is a memo editor, which would risk reopening keyboards for search, login, settings, lock dialogs, and other unrelated inputs.

Alternative considered: copy lifecycle code into all three screen states. Rejected because the behavior is shared and would leave reusable lifecycle logic hidden inside screen files, worsening checklist item `4.`.

### Decision: Restore only when the keyboard was visible before backgrounding

On `inactive`, `hidden`, or `paused`, the helper records a restore intent only if all of these are true:

- platform is Android
- the surface is eligible and mounted
- the editor focus node has focus
- the current route/surface is still current
- `MediaQuery.viewInsets.bottom > 0`, meaning the keyboard was visible

On `resumed`, the helper restores only if that intent was recorded and the same surface is still eligible/current. This avoids surprising keyboard pops when the user had already dismissed the keyboard or moved focus before leaving the app.

Alternative considered: restore whenever the editor `FocusNode` has focus after resume. Rejected because a focused editor can remain focused even after the user intentionally hid the keyboard.

### Decision: Schedule restoration after resume/layout settles

On resume, the helper should schedule restoration after a frame and a short delay before re-checking guards and invoking keyboard show. The restore path should:

1. Re-check Android platform, route currentness, eligibility, and focus ownership.
2. Request focus if needed.
3. Ask the platform text input to show the keyboard.

The extra delay is pragmatic: Android activity resume, Flutter frame rebuild, modal route state, and `MediaQuery.viewInsets` updates can race each other immediately after app resume.

Alternative considered: call show immediately inside `didChangeAppLifecycleState(AppLifecycleState.resumed)`. Rejected because it is more likely to be ignored by the platform or run while a modal route is still settling.

### Decision: Surface-specific eligibility stays local

The shared helper should not know memo business state. Each owner supplies a small predicate:

- `NoteInputSheet`: mounted, route current, not busy, compact or full-screen editor still visible.
- `MemoEditorScreen`: mounted, route current, not saving, editor enabled.
- `MemosListScreen`: mounted, route current, compose is enabled, inline compose is the active/visible compose surface, and the inline compose editor remains the focus owner.

This keeps policy reusable without pulling feature screen state into lower layers.

## Risks / Trade-offs

- Android or OEM IME may ignore the first show request after resume. -> Mitigate by waiting for a frame plus a short delay and by manually verifying on Android devices/emulators.
- The keyboard could reopen unexpectedly if the guard is too broad. -> Mitigate by requiring prior visible keyboard, same editor focus ownership, current route, and surface eligibility.
- Pure Flutter widget tests cannot fully assert system IME visibility. -> Mitigate with unit/widget tests for restore intent and injected show callback, plus Android manual verification.
- App lock or another modal could appear on resume. -> Mitigate by checking route currentness immediately before showing the keyboard.

## Migration Plan

No data migration is required. The change is a localized Flutter behavior fix.

Implementation can be rolled back by removing the feature-local helper wiring from the three editor surfaces. Drafts, memo mutation, sync, attachments, and persisted preferences are unaffected.

## Open Questions

- The exact restore delay should be selected during implementation. Start with a short delay such as 80-150 ms and keep it centralized in the helper so it is easy to tune.
