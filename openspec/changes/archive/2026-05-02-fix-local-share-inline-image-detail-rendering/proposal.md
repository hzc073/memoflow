## Why

本地模式下，第三方剪藏 memo 在 `LocalSync` 完成后会把 inline image URL 迁移到 `file:///.../local_attachments/...` private attachment path；但 memo 详情页的正文 HTML sanitizer 当前只允许 `http` / `https` image sources，导致正文内联 `<img>` 被移除，图片只能退回到附件宫格或完全不可见。

这需要单独修复，因为 `file:///` 是 `Uri.file(...)` 生成本地绝对路径的规范形式；把它改成 `file://` 只是改变 URI 解析语义，不能作为稳定方案。

## What Changes

- Extend detail inline image rendering so current memo-owned local attachment `file:` URLs can survive sanitization and render inline inside `MemoMarkdown`.
- Keep `file:///` as the canonical local file URL format; do not normalize or recommend `file://` as a workaround.
- Introduce a narrow allowlist seam for local inline image URLs derived from the current memo content/attachments, instead of globally allowing arbitrary `file:` URLs.
- Ensure inline-rendered local attachment images are not duplicated in the detail page attachment grid.
- Preserve remote Memos file URL auth behavior for `/file/...`, same-origin absolute URLs, and server-version rebase flags.
- Add focused regression coverage for sanitizer behavior, detail resolved data/render flags, local inline rendering, and duplicate-grid suppression.
- No database schema, API route, request/response model, commercial/private hook, or sync payload format changes are planned.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `memo-inline-image-rendering`: Add requirements for memo detail pages to safely render current memo-owned local attachment `file:` inline images, while continuing to block non-allowlisted local file URLs.

## Impact

- Affected runtime areas:
  - `memos_flutter_app/lib/features/memos/memo_detail_screen.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memo_reader_content.dart`
  - `memos_flutter_app/lib/features/memos/memo_markdown.dart`
  - `memos_flutter_app/lib/features/memos/memo_render_pipeline.dart`
  - `memos_flutter_app/lib/features/memos/memo_html_sanitizer.dart`
  - `memos_flutter_app/lib/features/memos/memo_image_grid.dart`
- Affected tests:
  - `memos_flutter_app/test/features/memos/memo_detail_screen_test.dart`
  - `memos_flutter_app/test/features/memos/memo_html_sanitizer_test.dart`
  - `memos_flutter_app/test/features/memos/memo_render_pipeline_contract_test.dart`
  - `memos_flutter_app/test/features/memos/memo_image_grid_test.dart`
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched:
  - `4.` No reused shared domain logic hidden inside screen or widget files.
  - `7.` Touched write paths have clear owners such as services, repositories, or mutation seams.
  - `10.` Every change touching a coupled area leaves that area equal or better structured than before.
- Scoped modularity improvement: centralize local inline image allowlist/ownership rules in a reusable feature-level rendering seam rather than scattering sanitizer exceptions inside detail widgets.
