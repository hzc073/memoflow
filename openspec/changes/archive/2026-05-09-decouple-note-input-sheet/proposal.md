## Why

`memos_flutter_app/lib/features/memos/note_input_sheet.dart` has grown to 4000+ lines and currently mixes sheet presentation, compose state coordination, attachment staging, deferred share media preparation, draft persistence, sync triggers, and submission orchestration. This makes the note input surface risky to evolve, especially after compact/full-screen compose support added more layout code to the same file.

The active architecture phase is `evolve_modularity`. This change touches modularity checklist items `1` (`state -> features` reverse dependencies), `2` (`application -> features` reverse dependencies through note input entry points), and `4` (shared domain/application logic hidden inside screen or widget files), so the plan must include scoped boundary improvements rather than only moving code around.

## What Changes

- Split `NoteInputSheet` into a small feature presentation shell plus focused helpers for compact/full-screen layout, toolbar wiring, chips/location display, and attachment preview rendering.
- Move non-UI compose orchestration out of the widget where practical: draft snapshot/restore, submit payload assembly, pending attachment staging, deferred inline image handling, and deferred share video preparation should be owned by state/application seams or feature-local coordinators with plain request/result models.
- Extract reusable pure helpers currently duplicated in screens, especially MIME type resolution and attachment/media classification, into stable non-widget modules.
- Reduce or isolate known dependency hotspots related to note input, including `state/memos/memo_composer_controller.dart -> features/memos/tag_autocomplete.dart`, by moving reusable tag query/suggestion logic out of feature UI files.
- Add or tighten focused tests and architecture guardrails so future note input changes do not reintroduce shared business logic into `note_input_sheet.dart` or expand reverse-dependency allowlists.
- Preserve current user behavior for compact compose, full-screen compose, drafts, attachments, linked memos, location, visibility, deferred share media, voice fallback, and submit/sync behavior.
- No breaking changes to user-facing APIs, Memos server compatibility, database schema, sync payloads, or public/private extension seams.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `note-input-sheet`: Adds architecture requirements for keeping `NoteInputSheet` presentation-focused while preserving existing compose behavior during decoupling.

## Impact

- Primary files: `memos_flutter_app/lib/features/memos/note_input_sheet.dart`, related feature-local widgets/helpers under `lib/features/memos/`, and note input compose controllers/providers under `lib/state/memos/`.
- Likely supporting files: shared pure helpers under `lib/core/` or `lib/application/attachments/`, existing attachment staging services, draft repositories/providers, tag autocomplete logic, and architecture tests under `memos_flutter_app/test/architecture/`.
- Tests: focused widget tests for compact/full-screen note input behavior, state/application unit tests for extracted orchestration, and architecture guardrails for dependency direction and screen-file responsibility.
- API/data compatibility: no server route, request/response model, version compatibility, or `lib/data/api` change is intended. Any later API-related edit would require explicit approval before implementation.
