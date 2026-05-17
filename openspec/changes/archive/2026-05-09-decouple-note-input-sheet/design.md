## Context

`NoteInputSheet` currently acts as a screen, controller, media workflow coordinator, draft session manager, and submit adapter in one file. Recent full-screen compose work correctly reused one `MemoComposerController`, but it also added more presentation branches to a file that already owned attachment staging, deferred inline image downloads, deferred video download/compression progress, MIME guessing, linked memo relation mapping, draft persistence, and sync triggering.

Existing seams that should be reused rather than bypassed:

- `MemoComposerController` owns text editing, markdown actions, undo/redo, pending attachments, linked memos, and tag autocomplete state.
- `NoteInputController` owns memo creation and deferred third-party inline image append behavior.
- `QueuedAttachmentStager` owns managed draft/upload file staging.
- `ComposeDraftRepository` / `NoteDraftRepository` own draft persistence.
- `ThirdPartyShareAttachmentAppender` owns post-submit third-party media attachment mutation.

Current hotspots relevant to this change:

- `note_input_sheet.dart` hides reusable application/domain behavior inside a feature widget, affecting checklist item `4`.
- `state/memos/memo_composer_controller.dart` imports `features/memos/tag_autocomplete.dart`, affecting checklist item `1`.
- `state/memos/note_input_controller.dart` currently depends on share feature models, and note input entry points are allowlisted from `application/startup`, affecting checklist items `1` and `2`.
- Existing specs already require shared deferred video attachment logic to not remain available only inside `NoteInputSheet`.

## Goals / Non-Goals

**Goals:**

- Make `NoteInputSheet` primarily a composition/presentation shell for compact and full-screen compose.
- Preserve compact/full-screen behavior, focus, draft save/restore, submit, attachment previews, visibility, linked memos, location, deferred media, and voice fallback.
- Extract reusable logic behind stable owners: pure helpers, state controllers, application attachment/share services, or feature-local widgets.
- Remove at least one concrete reverse dependency or shrink the architecture allowlist as part of the implementation.
- Add focused guardrails that prevent `note_input_sheet.dart` from becoming the owner of shared compose/media logic again.

**Non-Goals:**

- No server API, route adapter, version compatibility, database schema, or sync payload format changes.
- No visual redesign beyond preserving current compact/full-screen note input behavior.
- No private/commercial hook changes.
- No broad rewrite of `MemoEditorScreen`, desktop quick input, or unrelated memo list behavior.
- No phase transition from `evolve_modularity` to `preserve_modularity`.

## Decisions

### 1. Use incremental extraction, not a big-bang rewrite

Implementation should proceed in small behavior-preserving slices:

1. Extract pure helpers and tests.
2. Extract presentation widgets that receive state and callbacks.
3. Extract orchestration/coordinator seams.
4. Tighten architecture guardrails and allowlists.

Rationale: the sheet has many side effects and async flows. Small slices make regressions easier to isolate and allow each step to run focused tests.

Alternative considered: rewrite the sheet around a new provider/controller first. Rejected because it would couple many behavior changes to a high-risk UI surface.

### 2. Split presentation into feature-local widgets

Create focused widgets under `lib/features/memos/widgets/` or a `note_input/` subfolder for:

- compact sheet chrome/body
- full-screen compose surface
- full-screen toolbar strip and lightweight send/visibility controls
- linked memo chips and location state
- attachment/deferred media preview tiles

These widgets should take plain values, `MemoComposeToolbarActionSpec` lists, `TextEditingController` / `FocusNode` where needed, and callbacks. They should not directly read Riverpod providers or own staging/submission logic.

Before dependency direction:

```text
features/memos/note_input_sheet.dart
  -> state providers, application services, share services, file system APIs, UI widgets
```

After dependency direction:

```text
features/memos/note_input_sheet.dart
  -> feature-local presentation widgets
  -> state/application seams for behavior

features/memos/note_input/* presentation widgets
  -> Flutter UI, feature-local UI models, callback props
```

### 3. Move reusable tag autocomplete logic below feature UI

Move pure tag query/suggestion logic (`ActiveTagQuery`, `detectActiveTagQuery`, ranking/suggestion helpers) out of `features/memos/tag_autocomplete.dart` into a lower-layer state helper such as `state/memos/memo_tag_autocomplete.dart`. Keep `TagAutocompletePanel` and `TagAutocompleteOverlay` in the feature UI file.

Before:

```text
state/memos/memo_composer_controller.dart
  -> features/memos/tag_autocomplete.dart
```

After:

```text
state/memos/memo_composer_controller.dart
  -> state/memos/memo_tag_autocomplete.dart

features/memos/tag_autocomplete.dart
  -> state/memos/memo_tag_autocomplete.dart
```

This removes a concrete `state -> features` reverse dependency from the allowlist without changing UI behavior.

### 4. Give MIME resolution a stable pure owner

Extract the repeated `_guessMimeType` logic into a pure helper, for example `core/attachment_mime_type.dart`, with unit coverage. Then migrate note input, memo editor, desktop quick input, importers, and share video preparation opportunistically where touched.

Rationale: MIME guessing is shared logic currently duplicated across feature, state, and application files. `core` is appropriate only if the helper remains dependency-free.

### 5. Move note input submit assembly into a coordinator/request model

Introduce a plain request model, for example `NoteInputSubmitDraft`, containing content, visibility, location, relations, pending attachments, deferred inline image requests, and clip metadata. A state-layer or application-layer coordinator should turn that request into:

- `Attachment` JSON placeholders
- `NoteInputPendingAttachment` upload payloads
- tags
- `noteInputControllerProvider.createMemo(...)` calls
- post-create deferred inline image appends
- best-effort sync requests

`NoteInputSheet` should keep only UI decisions such as "empty content opens voice recording" and "show this snackbar/toast on failure".

Before:

```text
features/memos/note_input_sheet.dart
  -> builds memo payloads
  -> filters inline images
  -> creates memo
  -> appends deferred inline images
  -> requests sync
```

After:

```text
features/memos/note_input_sheet.dart
  -> collects UI state into NoteInputSubmitDraft
  -> calls note input submit coordinator

state/application note input coordinator
  -> note input mutation services
  -> queued attachment staging
  -> sync coordinator
```

### 6. Extract draft session behavior from widget lifecycle code

Create a small draft session helper/coordinator that owns:

- building `ComposeDraftSnapshot`
- restoring linked memos, attachments, inline image source mappings, visibility, and location
- saving current draft and legacy note draft consistently
- clearing active draft state after submit

The widget may still call the helper from lifecycle events, but snapshot construction and restore mapping should stop living inside the screen file.

### 7. Extract deferred share media orchestration behind a reusable seam

Move deferred inline image and deferred video processing out of `NoteInputSheet` into a coordinator with progress callbacks and cancellation/removal methods. The coordinator should use plain request/result/progress models so it can be reused by other share flows and tested without widget pumping.

Dependency improvement path:

- Move or mirror plain share request models out of `features/share` before lower layers depend on them.
- Keep UI prompts such as compression confirmation in the widget via callback interfaces.
- Keep `ShareVideoAttachmentPreparer` or its successor outside `NoteInputSheet` so shared deferred video logic is not sheet-private.

### 8. Tighten guardrails after extraction

After the code moves, update architecture tests to:

- remove the `memo_composer_controller.dart -> tag_autocomplete.dart` allowlist entry once the import is gone
- prevent `lib/state/**` from importing the note input/tag autocomplete UI files again
- optionally add a focused screen-responsibility guardrail that flags high-risk logic imports or helper names inside `note_input_sheet.dart`

The guardrail should be specific enough to catch regression without blocking legitimate UI composition.

## Risks / Trade-offs

- [Risk] Async media and draft flows regress during extraction. -> Mitigation: move one workflow at a time and add unit tests for extracted coordinators before removing old inline code.
- [Risk] Presentation widgets become callback-heavy. -> Mitigation: group callback/value props into small feature-local view models where it improves readability, but keep them UI-only.
- [Risk] Moving share models creates import churn. -> Mitigation: move plain models first and leave compatibility exports temporarily when possible.
- [Risk] Architecture guardrails become brittle. -> Mitigation: prefer dependency-direction tests and small allowlist reductions over line-count-only checks.
- [Risk] The file remains large after the first extraction. -> Mitigation: define success by responsibility boundaries and tests first; line count reduction is a useful outcome, not the primary contract.

## Migration Plan

1. Add tests around pure helpers and coordinator behavior before or alongside extraction.
2. Extract tag autocomplete pure logic and shrink the `state -> features` allowlist.
3. Extract MIME helper and update note input usage.
4. Extract presentation widgets while preserving existing widget tests.
5. Extract draft and submit coordinators with focused unit tests.
6. Extract deferred share media coordinator and preserve progress/cancellation behavior.
7. Run focused note input tests, `flutter test test/features/memos`, architecture tests, `flutter analyze`, and then broader `flutter test` if runtime scope is large.

Rollback strategy: each extraction should be independently revertible because it preserves public behavior and does not change persistence/API formats.

## Open Questions

- Should the final note input submit coordinator live in `state/memos` beside `NoteInputController`, or in `application/memos` with Riverpod providers in `state/memos`? The implementation should choose the least disruptive option that avoids new reverse dependencies.
- Should application startup keep directly importing `NoteInputSheet`, or should a module-boundary presenter seam be introduced in this change? If startup files are touched, prefer a boundary seam; otherwise leave the existing allowlist unchanged.
- How strict should the `note_input_sheet.dart` responsibility guardrail be? Start with dependency allowlist reductions and add a targeted screen-file guardrail only for extracted responsibilities with clear owners.
