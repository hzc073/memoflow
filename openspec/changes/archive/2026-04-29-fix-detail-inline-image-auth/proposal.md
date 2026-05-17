## Why

Clipped article memos can rewrite inline images to authenticated Memos attachment file URLs, but the memo detail rich-text path can render those URLs without the current account authorization header. On private or authenticated servers this produces intermittent-looking inline image preview failures with `401` responses even after upload and sync complete.

## What Changes

- Thread the memo detail resolved image request context (`baseUrl`, `authHeader`, `rebaseAbsoluteFileUrlForV024`, and `attachAuthForSameOriginAbsolute`) into the `_CollapsibleText` rich-text path.
- Pass that context from `_CollapsibleText` into its internal `MemoMarkdown` so same-origin and relative `/file/...` image requests can attach authorization consistently with list and reader paths.
- Add a focused regression test covering the memo detail `contentOverride` / `_CollapsibleText` path so future detail rendering changes do not drop Markdown image authorization.
- No API routes, request/response models, backend compatibility rules, or persisted models change.

## Capabilities

### New Capabilities
- `memo-inline-image-rendering`: Covers authenticated rendering behavior for inline Markdown/HTML images embedded in memo content, especially clipped article images rewritten to Memos attachment file URLs.

### Modified Capabilities
- None.

## Impact

- Affected runtime code is expected to stay within `memos_flutter_app/lib/features/memos/memo_detail_screen.dart` and its existing `MemoMarkdown` integration.
- Affected tests are expected under `memos_flutter_app/test/features/memos/`, focused on detail-page inline image authorization propagation.
- Active architecture phase: `evolve_modularity`.
- Modularity checklist impact: item 4 is touched because reusable memo-document rendering logic currently lives in `memo_detail_screen.dart`. This change should leave the touched area no worse by keeping the fix narrowly scoped and adding a guardrail test for the existing seam rather than introducing new cross-layer dependencies.
- No new dependencies, public/private extension seams, commercial logic, or API compatibility behavior are introduced.
