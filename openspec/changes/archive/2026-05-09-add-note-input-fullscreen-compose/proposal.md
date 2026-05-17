## Why

The current mobile add-memo flow opens `NoteInputSheet` as a bottom sheet. This works well for quick capture, but longer writing feels cramped because the editor shares a small vertical space with attachment previews, toolbar rows, visibility control, and the send/voice button.

The explored UI direction keeps the quick bottom-sheet entry, then lets the user expand into a full-screen writing mode. The full-screen mode should preserve the existing compose behavior while reallocating space:

```text
Current quick capture
  bottom sheet
  editor above
  toolbar + visibility + send below

Target full-screen writing
  full-height surface
  compact top toolbar row
  compact second toolbar row with visibility + send
  large editor area below
```

## What Changes

- Add a full-screen compose mode reachable from the add-memo bottom sheet via an embedded expand button in the sheet header area.
- In full-screen mode, remove the title text and use the top-left area as the first toolbar row.
- Keep the top-right area for window controls: collapse full-screen and close.
- Keep a second compact toolbar row below the first row, with lower-priority tools plus visibility and a lightweight send button on the right.
- Preserve the same compose draft, attachments, linked memos, location, visibility, tag autocomplete, toolbar preferences, voice/send behavior, and submit behavior across compact and full-screen modes.
- Keep the visual language aligned with current `MemoFlowPalette` surfaces and Material icon sizing.
- No API route, request/response model, database schema, sync payload, billing/private hook, or public/private split changes are planned.

## Capabilities

### Modified Capabilities

- `note-input-sheet`: Add an expanded full-screen writing presentation for add-memo composition.

## Impact

- Affected runtime areas:
  - `memos_flutter_app/lib/features/memos/note_input_sheet.dart`
  - `memos_flutter_app/lib/features/memos/compose_toolbar_shared.dart` if compact toolbar reuse needs small presentational extension points
  - adjacent `features/memos` compose helper widgets if extraction is needed to avoid duplicating toolbar/editor logic
- Affected tests:
  - Existing note input sheet/widget coverage if present
  - New focused widget tests for compact-to-full-screen transition, toolbar placement, close/collapse behavior, and state preservation
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched:
  - `4.` No reused shared domain logic hidden inside screen or widget files.
  - `7.` Touched write paths have clear owners such as services, repositories, or mutation seams.
  - `10.` Every change touching a coupled area leaves that area equal or better structured than before.
- Scoped modularity improvement: if the full-screen UI would otherwise duplicate compose toolbar/editor construction, extract a small feature-local presentation helper inside `features/memos` while keeping state ownership in the existing `MemoComposerController` path.
