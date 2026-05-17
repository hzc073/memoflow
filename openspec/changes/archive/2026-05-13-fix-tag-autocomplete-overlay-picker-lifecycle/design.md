# Design: Tag autocomplete overlay lifecycle

## Context

The reported path is:

```text
MemoEditorScreen opens existing memo
  -> caret is collapsed at the end
  -> trailing text is an active #tag token
  -> TagAutocompleteOverlay inserts a root OverlayEntry
  -> user opens Android photo picker
  -> root OverlayEntry remains visible
```

The root cause is likely not the tag matcher itself. The matcher is doing what it was designed to do: a collapsed caret inside `#tag` creates an active tag query. The lifecycle problem is that the visual suggestion panel is inserted into the root overlay and is not tied tightly enough to the editor interaction lifecycle.

## Decision

Prefer shared overlay lifecycle ownership over one-off picker fixes.

`TagAutocompleteOverlay` should be responsible for removing its own `OverlayEntry` when the owning editor is no longer allowed to show suggestions. The parent compose surface can still provide the show/hide predicate, but once an overlay has inserted into the root overlay, the overlay component must remove it promptly when that predicate becomes false or when the owning focus node loses focus.

Implementation should likely add an explicit lifecycle input to `TagAutocompleteOverlay`, for example an owning `FocusNode` or a `visible`/`enabled` signal, then use it to remove the `OverlayEntry` without waiting for unrelated parent rebuilds.

```text
Before

parent build predicate true
  -> TagAutocompleteOverlay widget exists
  -> root OverlayEntry exists
  -> focus loss may not rebuild parent immediately
  -> root OverlayEntry can remain visible

After

parent build predicate true
  -> TagAutocompleteOverlay widget exists
  -> root OverlayEntry exists
  -> owning focus/lifecycle becomes inactive
  -> overlay removes root OverlayEntry immediately
```

## Picker Boundary Rule

External picker launch points should explicitly end autocomplete interaction before calling plugin/platform picker APIs.

This is a UX rule, not just a defensive cleanup:

```text
toolbar button tap
  -> dismiss tag autocomplete / unfocus editor
  -> launch picker
  -> picker result returns
  -> do not automatically reopen tag suggestions
```

This should apply to:

- Android gallery/photo picker through `pickGalleryAttachments`.
- File picker attachment flow.
- Camera capture flow.

## Surface Coverage

The issue is reported in `MemoEditorScreen`, but the shared component is also used by:

- `MemoEditorScreen`
- `NoteInputSheet`
- `MemosListInlineComposeCard`
- `NoteInputFullscreenCompose`

The implementation should avoid fixing only the editor path if the shared overlay component can solve the root overlay lifecycle for all surfaces.

## Interaction Details

Expected behavior:

- If the editor remains focused and the caret remains in an active tag query, suggestions may stay visible.
- If the editor loses focus, suggestions disappear.
- If a platform/plugin picker is launched, suggestions disappear before or as the picker opens.
- When the picker returns, suggestions should not reappear automatically unless the user resumes editing in an active tag query.
- Applying a suggestion still refocuses the editor as it does today.
- Keyboard navigation behavior for suggestions remains unchanged.

## Architecture Notes

This change should stay within feature UI and existing state helpers:

```text
features/memos/* compose UI
  -> features/memos/tag_autocomplete.dart
  -> state/memos/memo_tag_autocomplete.dart
```

It must not introduce:

- `state -> features` imports.
- `application -> features` imports.
- `core -> state|application|features` upward imports.
- API-layer changes.

## Risks

- If focus is unfocused before every picker launch, the soft keyboard may close. That is acceptable for an external picker boundary, but implementation should not unfocus for formatting toolbar actions that intentionally operate on the current selection.
- If the overlay only watches focus loss, it may still remain when tags become empty or value changes without focus loss. The existing widget update path should continue removing the entry for empty tags; tests should cover both focus loss and empty suggestions.
- If picker return restores focus automatically on some platforms, suggestions could reappear. The implementation should not explicitly refocus after picker return.

