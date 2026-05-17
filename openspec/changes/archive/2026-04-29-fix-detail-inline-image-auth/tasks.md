## 1. Detail Rendering Propagation

- [x] 1.1 Add Markdown image request context fields to `_CollapsibleText` in `memos_flutter_app/lib/features/memos/memo_detail_screen.dart`.
- [x] 1.2 Pass `resolvedData.baseUrl`, `resolvedData.authHeader`, `resolvedData.rebaseAbsoluteFileUrlForV024`, and `resolvedData.attachAuthForSameOriginAbsolute` from `MemoDocumentPrimaryContent` into `_CollapsibleText`.
- [x] 1.3 Pass the same context from `_CollapsibleTextState.build` into its internal `MemoMarkdown`.
- [x] 1.4 Confirm collapsed content still disables inline image rendering through the existing `widget.renderImages && !showCollapsed` condition.

## 2. Focused Guardrail Test

- [x] 2.1 Add a focused widget test under `memos_flutter_app/test/features/memos/` that builds `MemoDocumentPrimaryContent` with `MemoDocumentResolvedData` containing `baseUrl`, `authHeader`, and both server-version image flags.
- [x] 2.2 Verify the descendant `MemoMarkdown` in the detail `contentOverride` path receives the same `baseUrl`, `authHeader`, `rebaseAbsoluteFileUrlForV024`, and `attachAuthForSameOriginAbsolute` values.
- [x] 2.3 Include inline clipped-article image content with a `/file/attachments/...` or same-origin attachment URL so the test represents the reported failure mode.

## 3. Verification

- [x] 3.1 Run the focused memo detail/Markdown test file from `memos_flutter_app`.
- [x] 3.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 3.3 Run `flutter test` from `memos_flutter_app` or document any unrelated pre-existing failures.
