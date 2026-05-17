## Why

GitHub issue #184 反馈 `1.0.30` 版本首页 memo 缩略图出现拉伸变形。当前 memo 卡片网格和发布前附件预览的视觉目标本来是用 `BoxFit.cover` 填充并裁切，但现有 decode/cache 尺寸路径可能先把图片强制压到 tile 宽高，再交给 `BoxFit.cover` 渲染，导致部分缩略图看起来像被挤压，而不是按比例裁切。

## What Changes

- 确保首页 memo 图片缩略图在填满网格 tile 时保持源图比例，并通过居中裁切处理超出区域。
- 确保发布前 composer pending image attachment 预览也保持源图比例，避免添加图片后的 62px 方形预览被压扁。
- 调整缩略图 decode/cache 尺寸策略，使其只作为性能优化，而不是变成视觉缩放契约。
- 保持全屏 preview/gallery 的渲染行为不变。
- 为 memo 缩略图 tile、composer pending attachment tile 渲染和 aspect-safe cache sizing 增加聚焦回归测试。
- 在当前 `evolve_modularity` 架构阶段下，将可复用的缩略图尺寸逻辑放在稳定 helper seam 中，而不是复制到 widget 代码里。

## Capabilities

### New Capabilities
- `memo-thumbnail-rendering`: 定义 memo 卡片图片缩略图的渲染契约，包括比例保持、裁切行为和 cache sizing 期望。

### Modified Capabilities
- None.

## Impact

- 预计影响的 UI 代码：
  - `memos_flutter_app/lib/features/memos/memo_media_grid.dart`
  - `memos_flutter_app/lib/features/memos/memo_image_grid.dart`
  - `memos_flutter_app/lib/features/memos/note_input_sheet.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_inline_compose_card.dart`
  - `memos_flutter_app/lib/features/image_preview/widgets/image_preview_tile.dart`
  - `memos_flutter_app/lib/core/image_thumbnail_cache.dart`
- 预计影响的测试：
  - `memos_flutter_app/test/features/memos/...`
  - `memos_flutter_app/test/features/memos/widgets/...`
  - `memos_flutter_app/test/features/image_preview/...`
  - `memos_flutter_app/test/core/image_thumbnail_cache_test.dart`
- 不计划修改 server API、request/response model、route adapter、sync format、database schema 或 commercial/private extension 行为。
- 涉及的 modularity checklist：
  - `4.` 通过把 aspect-safe thumbnail cache sizing 集中到稳定 helper，避免复用型显示逻辑隐藏在 screen/widget 文件中。
  - `10.` 在 `evolve_modularity` 阶段，保证被触及的图片渲染区域保持同等或更好的结构。
