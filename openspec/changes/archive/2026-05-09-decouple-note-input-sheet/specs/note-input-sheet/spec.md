## ADDED Requirements

### Requirement: Note input sheet keeps presentation separate from compose behavior
`NoteInputSheet` SHALL remain the presentation entry point for note composition, but reusable compose behavior SHALL be owned by focused helpers, controllers, coordinators, or services outside the screen widget.

#### Scenario: Presentation widgets receive state and callbacks
- **WHEN** compact or full-screen note input UI is rendered after the decoupling
- **THEN** feature-local presentation widgets SHALL receive render state and callbacks rather than directly owning draft persistence, attachment staging, deferred media processing, memo mutation, or sync orchestration

#### Scenario: Shared behavior is not hidden in the screen file
- **WHEN** compose behavior is needed by note input and another compose surface or share flow
- **THEN** the reusable behavior SHALL live in a stable helper, controller, coordinator, provider, or application service instead of being available only inside `note_input_sheet.dart`

### Requirement: Note input decoupling preserves existing compose behavior
The note input decoupling SHALL preserve current compact and full-screen compose behavior while moving responsibilities to smaller owners.

#### Scenario: Presentation mode toggles preserve compose state
- **WHEN** the user switches between compact and full-screen note input
- **THEN** text, selection, focus target, attachments, linked memos, location, visibility, deferred media progress, and draft identity SHALL remain intact

#### Scenario: Submit behavior remains equivalent
- **WHEN** the user submits from compact or full-screen note input after decoupling
- **THEN** memo content, tags, visibility, location, relations, attachments, pending uploads, deferred inline image handling, local save toast behavior, and best-effort sync behavior SHALL match the pre-decoupling submit path

#### Scenario: Draft behavior remains equivalent
- **WHEN** the note input sheet is closed, restored from draft box, or cleared after submit
- **THEN** compose draft persistence, legacy note draft persistence, active draft selection, attachment preservation, and inline image source mappings SHALL match the pre-decoupling behavior

### Requirement: Note input decoupling improves touched modularity hotspots
While the project remains in `evolve_modularity`, note input decoupling SHALL leave touched architecture hotspots equal or better structured and SHALL NOT expand reverse-dependency allowlists.

#### Scenario: Tag autocomplete reverse dependency is removed
- **WHEN** reusable tag query or suggestion logic is extracted from note input UI
- **THEN** `state/memos/memo_composer_controller.dart` SHALL NOT import `features/memos/tag_autocomplete.dart`
- **AND** the corresponding `state -> features` guardrail allowlist entry SHALL be removed or tightened

#### Scenario: Lower layers avoid note input UI dependencies
- **WHEN** note input compose, draft, submit, or attachment logic is moved into `state`, `application`, or `core`
- **THEN** those lower-layer modules SHALL NOT import `features/memos/note_input_sheet.dart` or feature presentation widgets

#### Scenario: Shared attachment and MIME logic has stable owners
- **WHEN** MIME resolution, pending attachment staging requests, or deferred share media preparation is reused outside `NoteInputSheet`
- **THEN** the shared logic SHALL be owned by dependency-free helpers or state/application services with focused tests rather than duplicated in screen files
