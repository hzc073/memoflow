## Why

User-authored memo content can contain Markdown image links such as `![](https://...)`. Today those images are collected into the memo media grid and stripped from the rendered article body, so even after a user expands a long memo the image cannot be viewed at its authored position in the text.

The desired behavior matches the clipped-article reading experience without broadening ordinary memo HTML handling:

```text
Collapsed list card
  -> compact text preview
  -> image/video grid preview

Expanded list card / expanded detail body
  -> Markdown image syntax renders inline at its document position
  -> duplicated grid tiles are removed
  -> unreferenced attachments and videos remain in the trailing media grid
```

## What Changes

- Render ordinary Markdown image syntax `![](...)` inline when a memo body is expanded in the list card or detail view.
- Keep collapsed list/detail previews image-free in the Markdown body and continue to use the existing media grid for compact scanning.
- Do not enable raw HTML `<img>` tags for ordinary memos as part of this change; clipped/third-party share paths may continue to use their existing HTML image behavior.
- Keep local `file:` image rendering scoped to current memo-owned image attachments only, using the existing local inline image allowlist policy.
- Suppress duplicate media grid entries for images already rendered inline, while keeping unreferenced image attachments and videos eligible for the trailing grid.
- Add focused regression coverage for list card expansion, detail expansion/collapse, Markdown-only syntax filtering, local file allowlisting, duplicate suppression, and cache freshness.
- No API route, request/response model, database schema, sync payload format, commercial/private hook, or public/private split changes are planned.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `memo-inline-image-rendering`: Extend inline image rendering from clipped/third-party share article content to ordinary Markdown image syntax in expanded memo reading surfaces.

## Impact

- Affected runtime areas:
  - `memos_flutter_app/lib/features/memos/memo_render_pipeline.dart`
  - `memos_flutter_app/lib/features/memos/memo_markdown_preprocessor.dart`
  - `memos_flutter_app/lib/features/memos/memo_image_src_normalizer.dart`
  - `memos_flutter_app/lib/features/memos/memo_inline_image_sources.dart`
  - `memos_flutter_app/lib/features/memos/memo_detail_screen.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_memo_card.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_memo_card_container.dart`
  - adjacent memo media/grid helper files if duplicate suppression needs a shared helper
- Affected tests:
  - `memos_flutter_app/test/features/memos/memo_render_pipeline_contract_test.dart`
  - `memos_flutter_app/test/features/memos/memo_image_grid_test.dart`
  - `memos_flutter_app/test/features/memos/memo_detail_screen_test.dart`
  - `memos_flutter_app/test/features/memos/memos_list_memo_card_container_test.dart`
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched:
  - `4.` No reused shared domain logic hidden inside screen or widget files.
  - `6.` Feature-to-feature collaboration prefers boundary/registry/provider seams over direct screen imports.
  - `8.` Architecture guardrail tests protect the highest-risk dependency directions.
  - `10.` Every change touching a coupled area leaves that area equal or better structured than before.
- Scoped modularity improvement: introduce or extend a feature-level memo inline image rendering policy/helper so list card and detail rendering share the same syntax mode, local file ownership, duplicate suppression, and cache-key fingerprint decisions instead of duplicating that logic inside widget build methods.
