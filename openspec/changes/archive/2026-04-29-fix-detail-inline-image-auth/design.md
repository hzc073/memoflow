## Context

Clipped article content can contain inline Markdown/HTML images that are rewritten to Memos attachment file URLs such as `/file/attachments/...` or same-origin absolute URLs. `MemoMarkdown` already supports resolving these image URLs against `baseUrl` and attaching `Authorization` through `authHeader`.

The memo detail screen prepares the required context in `MemoDocumentResolvedData`, but the `MemoDocumentPrimaryContent` -> `_CollapsibleText` -> `MemoMarkdown` path currently drops that context. This path is used as a `contentOverride` for the detail reader body, so it bypasses the otherwise-correct `MemoReaderContent` Markdown construction path.

The active architecture phase is `evolve_modularity`. This change touches a known hotspot: reusable memo-document rendering logic still lives in `features/memos/memo_detail_screen.dart`, which relates to modularity checklist item 4. The proposal keeps the runtime change narrowly scoped and adds a focused guardrail test so this existing seam does not regress.

## Goals / Non-Goals

**Goals:**
- Ensure memo detail inline Markdown/HTML image requests receive the same URL resolution and authorization context already prepared in `MemoDocumentResolvedData`.
- Preserve current `MemoMarkdown` URL and header resolution behavior instead of duplicating auth logic in the detail screen.
- Add a focused regression test for the detail `contentOverride` / `_CollapsibleText` rendering path.
- Avoid new reverse dependencies or wider feature/module restructuring.

**Non-Goals:**
- No backend API, auth token format, or Memos server compatibility changes.
- No change to attachment upload, memo sync, remote rewrite, or database persistence behavior.
- No broad extraction of memo document rendering from `memo_detail_screen.dart`.
- No commercial/private extension behavior.

## Decisions

### Decision 1: Propagate existing auth context through `_CollapsibleText`

`MemoDocumentPrimaryContent` will pass `resolvedData.baseUrl`, `resolvedData.authHeader`, `resolvedData.rebaseAbsoluteFileUrlForV024`, and `resolvedData.attachAuthForSameOriginAbsolute` into `_CollapsibleText`. `_CollapsibleText` will expose matching fields and pass them to the internal `MemoMarkdown`.

Rationale: `MemoMarkdown` is already the owner of Markdown image URL resolution and `httpHeaders` selection. Threading existing context keeps ownership unchanged and minimizes the detail-screen patch.

Alternative considered: Add special-case image header handling directly in `_CollapsibleText`. Rejected because it would duplicate `MemoMarkdown.resolveMemoMarkdownRemoteImageRequest` logic and increase drift risk.

Alternative considered: Change backend file URLs or make attachment files public. Rejected because the observed failure is a client render-time missing-header issue and private memos must remain protected.

### Decision 2: Keep dependency directions unchanged

Before the change, the dependency direction is `features/memos/memo_detail_screen.dart` using `features/memos/memo_markdown.dart`. After the change, the direction remains the same; no `state -> features`, `application -> features`, or `core -> higher-layer` dependency is added.

Rationale: This is a local UI rendering propagation bug. Fixing it within the existing feature boundary avoids broad movement while preserving current architecture constraints.

### Decision 3: Add a focused detail-path guardrail test

The test should exercise `MemoDocumentPrimaryContent` with `MemoDocumentResolvedData` containing auth/base context and clipped article content with inline images. It should verify the `MemoMarkdown` created by the detail `contentOverride` path receives the auth/base fields needed to attach headers.

Rationale: Existing `MemoMarkdown` tests cover resolver behavior, and list/reader paths already pass context. The missing coverage is the detail wrapper path that dropped the context.

Alternative considered: Only add another resolver unit test. Rejected because the resolver already behaves correctly; the regression risk is parameter propagation through the private detail wrapper.

## Risks / Trade-offs

- [Risk] `_CollapsibleText` is private, so direct testing may be awkward. -> Mitigation: test through the public/importable `MemoDocumentPrimaryContent` and inspect the descendant `MemoMarkdown`.
- [Risk] `memo_detail_screen.dart` remains a large coupled file. -> Mitigation: keep the patch small and add a guardrail test without adding new dependencies; defer broader extraction to a dedicated modularity change.
- [Risk] Collapsed content intentionally disables image rendering. -> Mitigation: preserve the existing `renderImages: widget.renderImages && !showCollapsed` behavior while still passing auth context for expanded rendering.
- [Risk] Same-origin absolute URL behavior differs by server version flags. -> Mitigation: pass the existing resolved flags unchanged rather than recalculating them inside `_CollapsibleText`.

## Migration Plan

1. Update `_CollapsibleText` constructor and fields to accept the existing Markdown image auth context.
2. Pass the fields from `MemoDocumentPrimaryContent` using `resolvedData`.
3. Pass the fields from `_CollapsibleTextState.build` into `MemoMarkdown`.
4. Add the focused widget regression test.
5. Run the focused test file first, then broader Flutter checks when ready.

Rollback is straightforward: revert the UI propagation and test changes. No data migration or server migration is required.

## Open Questions

- None for the targeted fix.
