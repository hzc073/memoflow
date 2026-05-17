## Why

The existing memo editor already has a strong compose surface, but its mobile page presentation keeps the top-right AppBar action as `Save` even though the same screen also exposes a bottom circular save button. Meanwhile, the add-memo `NoteInputSheet` already has a full-screen writing presentation that gives users a larger editor and keeps compose controls available.

The explored direction is to extend that full-screen writing affordance to the existing memo editor: on the normal mobile page, replace the top-right save action with a full-screen editor entry. Save remains available through the existing bottom primary action and keyboard shortcuts. Desktop and embedded editor chrome should also stop showing duplicate header save actions when the bottom save action is present.

## What Changes

- Add a full-screen compose mode for `MemoEditorScreen` that stays in the same editor session rather than opening a new route.
- Replace the mobile normal-page AppBar top-right `Save` action with a full-screen entry action.
- Extract or introduce a feature-local shared full-screen compose presentation surface that can be used by both add-memo input and memo editing without mixing their primary action semantics.
- Keep note input full-screen behavior equivalent: send/voice remains a note-input-specific primary action.
- Make memo editor full-screen use a save/check primary action, not the note-input send/voice action.
- In full-screen editor mode, keep close and collapse controls in the top chrome; collapse returns to the normal editor layout without saving or prompting.
- Make full-screen editor close follow the existing draft-aware close path.
- Remove duplicate header save UI from desktop/embedded editor chrome where the bottom save action is already visible.
- Preserve existing editor draft, attachment, linked memo, location, visibility, tag autocomplete, toolbar, and save behavior.

## Capabilities

### New Capabilities

- `memo-editor-fullscreen-compose`: Defines the memo editor full-screen entry, shared full-screen compose surface expectations, save/close/collapse behavior, and duplicate save UI cleanup.

### Modified Capabilities

- `note-input-sheet` behavior is affected by refactoring risk only: its existing full-screen behavior should remain unchanged while moving shared presentation structure behind a feature-local reusable surface.

## Impact

- Affected UI: `memos_flutter_app/lib/features/memos/memo_editor_screen.dart`, `memos_flutter_app/lib/features/memos/widgets/note_input_fullscreen_compose.dart`, and likely a new shared widget under `memos_flutter_app/lib/features/memos/widgets`.
- Affected shared UI seam: full-screen compose layout becomes a feature-local presentation seam shared by note input and memo editor adapters.
- Affected tests: add or update widget tests for mobile editor full-screen entry, editor full-screen state preservation, close/collapse/save behavior, note input full-screen regression coverage, and desktop duplicate save cleanup.
- No API contract changes and no edits expected under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api`.
- No subscription, billing, entitlement, receipt, paywall, StoreKit, or private-extension behavior.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 4 (avoid hiding reused shared presentation/compose logic inside screen files), item 6 (feature collaboration prefers stable seams over ad hoc direct reuse), item 7 (save/write paths stay owned by existing editor controller and mutation seams), item 8 (tests guard high-risk UI behavior), and item 10 (touched coupled areas should be left equal or better structured).
- Modularity intent: extract the reusable full-screen compose presentation shape rather than duplicating note input full-screen layout in `MemoEditorScreen`.

## Non-Goals

- Do not change Memos server APIs, request/response models, route adapters, API compatibility tests, or sync version behavior.
- Do not change memo save mutation semantics, draft persistence semantics, attachment staging semantics, or sync orchestration.
- Do not remove the bottom circular save button from the memo editor.
- Do not make the memo editor primary action use note-input send/voice behavior.
- Do not redesign the normal memo editor layout beyond replacing/removing duplicate top save actions.
- Do not add commercial/private-extension logic.
