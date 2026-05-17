## 1. Baseline and Safety Checks

- [x] 1.1 Review current `note_input_sheet.dart` responsibilities and record the exact extraction order in the implementation notes before editing runtime code.
- [x] 1.2 Run or add focused baseline coverage for compact/full-screen mode toggling, text/visibility preservation, full-screen send, and draft-aware close behavior.
- [x] 1.3 Confirm no API/data-route files are needed for this refactor; if an API-related edit becomes necessary, stop and request explicit approval before continuing.

## 2. Remove Tag Autocomplete Reverse Dependency

- [x] 2.1 Extract `ActiveTagQuery`, `detectActiveTagQuery`, and tag suggestion ranking into a non-UI state helper such as `lib/state/memos/memo_tag_autocomplete.dart`.
- [x] 2.2 Update `MemoComposerController` and feature UI tag autocomplete widgets to import the new helper without changing keyboard or selection behavior.
- [x] 2.3 Move or update existing tag autocomplete tests so pure query/suggestion behavior is covered outside feature UI widgets.
- [x] 2.4 Remove or tighten the `memo_composer_controller.dart -> features/memos/tag_autocomplete.dart` allowlist entry in `test/architecture/modularity_dependency_guardrail_test.dart`.

## 3. Extract Shared Pure Helpers

- [x] 3.1 Add a dependency-free MIME resolution helper, for example `lib/core/attachment_mime_type.dart`, with unit tests for image, audio, video, document, text, and fallback extensions.
- [x] 3.2 Replace `_guessMimeType` usage in `note_input_sheet.dart` with the shared helper.
- [x] 3.3 Opportunistically update directly touched compose surfaces or media preparers that duplicate the same MIME mapping, keeping unrelated importers out of scope unless they are trivial.

## 4. Split Note Input Presentation Widgets

- [x] 4.1 Extract full-screen compose layout into a feature-local widget that receives editor state, toolbar actions, visibility/send state, chips, attachment preview, and callbacks.
- [x] 4.2 Extract compact sheet body/chrome into a feature-local widget while preserving the embedded expand control and keyboard inset behavior.
- [x] 4.3 Extract linked memo chips, location state, and send/progress button rendering into small UI-only helpers or widgets where this reduces `note_input_sheet.dart` responsibility.
- [x] 4.4 Extract attachment and deferred media preview tile rendering into UI-only widgets that do not own staging, submit, or media preparation logic.
- [x] 4.5 Keep `NoteInputSheet` as the composition shell that wires providers, controllers, callbacks, and presentation mode state.

## 5. Extract Draft and Submit Orchestration

- [x] 5.1 Introduce a draft session helper/coordinator for building `ComposeDraftSnapshot`, restoring selected drafts, tracking inline image source mappings, and clearing submitted draft state.
- [x] 5.2 Add a plain note input submit request model that captures content, visibility, location, relations, pending attachments, deferred inline image requests, and clip metadata.
- [x] 5.3 Move submit payload assembly, tag extraction, inline image attachment filtering, attachment JSON construction, pending upload mapping, memo creation, deferred inline image append, and best-effort sync request into a state/application coordinator.
- [x] 5.4 Keep UI-only submit decisions in `NoteInputSheet`, including empty-content voice fallback and user-facing snackbar/toast presentation.
- [x] 5.5 Add focused unit tests for draft restore/save mapping and submit request assembly, including inline image attachment filtering and relation preservation.

## 6. Extract Deferred Share Media Workflows

- [x] 6.1 Extract deferred inline image prefetch/submit processing into a coordinator with progress callbacks, cancellation-safe cleanup, and tests for skipped, applied, and failed downloads.
- [x] 6.2 Extract deferred share video processing state into a reusable coordinator or service that owns phase/progress transitions while delegating UI prompts through callbacks.
- [x] 6.3 Ensure shared deferred video attachment logic is no longer available only inside `NoteInputSheet`.
- [x] 6.4 Add tests for deferred video cancellation, compression-declined removal, compression failure reporting, and successful staged attachment admission.

## 7. Architecture Guardrails

- [x] 7.1 Add or tighten architecture tests so lower layers cannot import `features/memos/note_input_sheet.dart` or extracted note input presentation widgets.
- [x] 7.2 Add a focused guardrail that prevents `note_input_sheet.dart` from re-owning extracted shared responsibilities where the new owner is unambiguous.
- [x] 7.3 If application startup note input entry points are touched, introduce or preserve a boundary presenter seam rather than adding new `application -> features` imports.
- [x] 7.4 Verify no reverse-dependency allowlist grows as part of this change; any allowlist update should shrink or become more specific.

## 8. Verification

- [x] 8.1 Run focused tests for extracted state/application helpers and note input widgets.
- [x] 8.2 Run `flutter test test/features/memos` from `memos_flutter_app`.
- [x] 8.3 Run `flutter test test/architecture` from `memos_flutter_app`.
- [x] 8.4 Run `flutter analyze` from `memos_flutter_app`.
- [x] 8.5 Run full `flutter test` from `memos_flutter_app` if coordinator extraction touches submit, draft, attachment, or sync-adjacent behavior broadly.
