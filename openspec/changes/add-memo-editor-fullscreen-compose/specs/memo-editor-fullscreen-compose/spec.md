## ADDED Requirements

### Requirement: Memo editor mobile page exposes full-screen entry
The memo editor SHALL expose a full-screen compose entry from the normal mobile/page editor AppBar instead of a duplicate top save action.

#### Scenario: Existing memo editor page is shown
- **GIVEN** the user opens an existing memo in the normal page `MemoEditorScreen`
- **WHEN** the AppBar actions are rendered
- **THEN** the top-right AppBar action SHALL open full-screen compose mode
- **AND** the top-right AppBar action SHALL NOT be the save action
- **AND** the bottom primary save action SHALL remain available

#### Scenario: New memo editor page is shown
- **GIVEN** the user opens `MemoEditorScreen` for a new memo
- **WHEN** the AppBar actions are rendered
- **THEN** the top-right AppBar action SHALL open full-screen compose mode
- **AND** saving the new memo SHALL remain available through the editor save action path

### Requirement: Memo editor full-screen mode preserves the edit session
The memo editor full-screen compose mode SHALL reuse the same editor session and SHALL NOT create a separate editor route or independent draft session.

#### Scenario: User enters full-screen editor mode
- **GIVEN** the memo editor contains text, selection, attachments, linked memos, location, visibility, toolbar preferences, tag autocomplete state, or an active draft identity
- **WHEN** the user activates the full-screen entry
- **THEN** the editor SHALL switch to full-screen compose mode within the same `MemoEditorScreen` state
- **AND** the current text, selection, attachments, linked memos, location, visibility, toolbar preferences, tag autocomplete state, and draft identity SHALL be preserved
- **AND** the full-screen editor SHALL receive focus after the layout switch

#### Scenario: User collapses full-screen editor mode
- **GIVEN** the memo editor is in full-screen compose mode
- **WHEN** the user activates the collapse or restore control
- **THEN** the editor SHALL return to the normal editor layout
- **AND** the current edit session state SHALL be preserved
- **AND** the collapse action SHALL NOT save the memo
- **AND** the collapse action SHALL NOT trigger the close confirmation flow

### Requirement: Memo editor full-screen mode keeps editor-specific save semantics
The memo editor full-screen compose mode SHALL use editor-specific save semantics and SHALL NOT use note-input send or voice semantics.

#### Scenario: Full-screen editor primary action is shown
- **GIVEN** the memo editor is in full-screen compose mode
- **WHEN** the bottom toolbar primary action is rendered
- **THEN** the primary action SHALL represent saving the memo
- **AND** the primary action SHALL use save/check semantics
- **AND** the primary action SHALL NOT use note-input send, create-memo, or voice semantics

#### Scenario: User saves from full-screen editor mode
- **GIVEN** the memo editor is in full-screen compose mode
- **WHEN** the user activates the full-screen save action
- **THEN** the memo SHALL be saved through the same editor save path used by the normal editor save action
- **AND** the save action SHALL be emitted exactly once

### Requirement: Full-screen editor close remains draft-aware
The memo editor full-screen close control SHALL follow the existing memo editor close behavior.

#### Scenario: User closes unchanged full-screen editor
- **GIVEN** the memo editor is in full-screen compose mode
- **AND** the editor state has no unsaved changes
- **WHEN** the user activates the close control
- **THEN** the editor SHALL close through the existing close path without creating a visible edit draft

#### Scenario: User closes changed full-screen editor
- **GIVEN** the memo editor is in full-screen compose mode for an existing memo
- **AND** the editor has unsaved changes
- **WHEN** the user activates the close control
- **THEN** the existing unsaved-edit confirmation flow SHALL be used
- **AND** the user SHALL still be able to continue editing, discard changes, or add the edit to Draft Box

### Requirement: Shared full-screen compose surface preserves feature semantics
The shared full-screen compose presentation surface SHALL be presentation-only and SHALL preserve the distinct semantics of note input and memo editing.

#### Scenario: Note input uses the shared full-screen surface
- **GIVEN** `NoteInputSheet` is in full-screen compose mode
- **WHEN** the shared full-screen surface renders note input content
- **THEN** existing note input full-screen toolbar, visibility, close, collapse, send/voice, focus, draft, and submit behavior SHALL remain unchanged

#### Scenario: Memo editor uses the shared full-screen surface
- **GIVEN** `MemoEditorScreen` is in full-screen compose mode
- **WHEN** the shared full-screen surface renders memo editor content
- **THEN** the surface SHALL call editor-provided callbacks for save, close, collapse, toolbar actions, and visibility changes
- **AND** the surface SHALL NOT directly persist drafts, stage attachments, submit or save memos, request sync, or execute memo mutations

### Requirement: Duplicate memo editor header save UI is removed
Memo editor desktop and embedded chrome SHALL NOT expose a duplicate header save action when the bottom save action is visible.

#### Scenario: Desktop modal editor is shown
- **GIVEN** the memo editor is shown in desktop modal presentation
- **WHEN** the editor header is rendered
- **THEN** the header SHALL expose fullscreen or restore controls as applicable
- **AND** the header SHALL expose close controls
- **AND** the header SHALL NOT expose a duplicate save action
- **AND** the bottom save action SHALL remain available

#### Scenario: Desktop fullscreen editor is shown
- **GIVEN** the memo editor is shown in desktop fullscreen presentation
- **WHEN** the editor chrome is rendered
- **THEN** the chrome SHALL expose restore and close controls
- **AND** the chrome SHALL NOT expose a duplicate save action
- **AND** the bottom save action SHALL remain available

#### Scenario: Embedded editor is shown
- **GIVEN** the memo editor is shown in embedded pane presentation with editor chrome
- **WHEN** the embedded header is rendered
- **THEN** the header SHALL expose close controls when close is supported
- **AND** the header SHALL NOT expose a duplicate save action when the bottom save action is visible
- **AND** the bottom save action SHALL remain available

### Requirement: Memo editor full-screen change preserves architecture boundaries
The memo editor full-screen compose change SHALL preserve existing architecture boundaries and SHALL improve or preserve modularity in the touched compose/editor presentation area.

#### Scenario: Shared presentation is extracted
- **WHEN** the full-screen compose presentation is shared between note input and memo editor
- **THEN** the shared surface SHALL live under the feature presentation layer
- **AND** lower layers such as `state`, `application`, and `core` SHALL NOT import that presentation widget
- **AND** save/write behavior SHALL remain owned by existing editor controller, repository, provider, or mutation seams

#### Scenario: No API-related code is touched
- **WHEN** the memo editor full-screen compose change is implemented
- **THEN** no request/response models, route adapters, version compatibility logic, or files under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api` SHALL be changed
