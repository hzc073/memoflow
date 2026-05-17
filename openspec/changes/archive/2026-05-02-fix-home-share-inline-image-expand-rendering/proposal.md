## Why

本地模式第三方剪藏在 `LocalSync` 成功后会把正文 inline image URL 迁移到 `file:///.../local_attachments/...` private attachment path；详情页和通用阅读路径已有 scoped allowlist，但首页/list memo card 的展开正文仍未传入该 allowlist，导致展开后本地内联图片被 sanitizer 移除或无法进入 preview。

该问题现在暴露在完成同步后：日志显示 `upload_attachment` 全部成功、memo content/attachment metadata 已迁移到 private file URL，但用户在首页卡片展开后仍无法查看图片。

## What Changes

- Extend home/list memo card expanded article rendering so current memo-owned local attachment `file:` inline images are allowlisted and rendered inside `MemoMarkdown`.
- Keep collapsed card previews image-free; only expanded article body may render inline images.
- Reuse the existing `MemoInlineImageSourcePolicy` / sanitizer seam instead of globally allowing arbitrary local `file:` URLs.
- Ensure the home/list expanded markdown cache key changes when the local inline image policy or attachment source metadata changes.
- Preserve existing media grid behavior: non-expanded cards still rely on the media grid, and expanded clipped-article cards should not duplicate inline images in the grid.
- Add focused regression coverage for home/list card expansion, sanitizer allowlist propagation, and cache freshness.
- No API route, request/response model, database schema, sync payload format, commercial/private hook, or public/private split changes are planned.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `memo-inline-image-rendering`: Add home/list expanded card requirements for safely rendering current memo-owned local attachment `file:` inline images while continuing to block non-allowlisted local file URLs.

## Impact

- Affected runtime areas:
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_memo_card.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_memo_card_container.dart`
  - `memos_flutter_app/lib/features/memos/memo_inline_image_sources.dart`
  - `memos_flutter_app/lib/features/memos/memo_media_cache_key.dart` if cache-key reuse needs a shared fingerprint seam
- Affected tests:
  - `memos_flutter_app/test/features/memos/memos_list_memo_card_test.dart` or adjacent card widget coverage
  - `memos_flutter_app/test/features/memos/memo_inline_image_sources_test.dart`
  - `memos_flutter_app/test/features/memos/memo_render_pipeline_contract_test.dart` if sanitizer/cache behavior needs contract coverage
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched:
  - `4.` No reused shared domain logic hidden inside screen or widget files.
  - `6.` Feature-to-feature collaboration prefers boundary/registry/provider seams over direct screen imports.
  - `8.` Architecture guardrail tests protect the highest-risk dependency directions.
  - `10.` Every change touching a coupled area leaves that area equal or better structured than before.
- Scoped modularity improvement: keep local inline image ownership and fingerprint logic centralized in the existing memo rendering/source policy seam, and add/tighten focused tests so card rendering cannot drift from detail/reader behavior again.
