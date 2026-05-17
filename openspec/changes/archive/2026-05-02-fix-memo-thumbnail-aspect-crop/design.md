## Context

Issue #184 描述了 `1.0.30` 首页 memo 缩略图变形：图片看起来被拉伸，而不是保持原始比例并裁掉溢出部分。当前首页卡片路径通过 `MemoMediaGrid` / `MemoImageGrid` 和 `ImagePreviewTile` 渲染 memo media；视觉层已经倾向使用 `BoxFit.cover`，但 cache/decode 尺寸会从 tile width 和 tile height 同时推导并向下传递。

后续探索和用户补充截图还显示：添加图片后的发布前预览也可能被挤压。该路径主要在 `NoteInputSheet._buildAttachmentTile` 和 `MemosListInlineComposeCard` 的 `_InlineAttachmentTile` 中复用 `ImagePreviewTile`，并把同一个 62px `cacheExtent` 同时传给 `cacheWidth` 和 `cacheHeight`。因此这不是单个首页 grid 的孤立问题，而是 thumbnail caller 将 display tile shape 当成 exact decode shape 的共性风险。

这里有一个关键区别：

```text
期望视觉行为
source image ──preserve aspect──▶ cover tile ──crop overflow──▶ thumbnail

当前风险
source image ──exact decode/cache to tile W/H──▶ distorted bitmap ──cover──▶ thumbnail
```

当前架构阶段是 `evolve_modularity`。本变更局限在图片展示代码，不需要 API、data model、sync 或 routing 变更。它触及 modularity checklist item `4.` 的方式是：可复用的 thumbnail sizing 行为不应该继续隐藏在 widget build 方法里；计划改进是把 aspect-safe sizing 放在 `core/image_thumbnail_cache.dart` 或等价的稳定 helper 中，并且不引入 upward imports。

变更前 dependency direction：

```text
features/memos widgets ──▶ core/image_thumbnail_cache
features/image_preview/widgets ──▶ 通过调用方传入 extents 间接使用 core/image_thumbnail_cache
core ──X no dependency on features/state/application
```

变更后 dependency direction：

```text
features/memos widgets ──▶ core/image_thumbnail_cache aspect-safe helper
features/memos composer widgets ──▶ core/image_thumbnail_cache safe fallback
features/image_preview/widgets 继续保持 generic tile renderer
core ──X no dependency on features/state/application
```

## Goals / Non-Goals

**Goals:**

- 首页 memo 卡片图片缩略图保持源图比例，并通过居中裁切填满 tile。
- 发布前 composer pending image attachment 预览保持源图比例，并通过居中裁切填满 62px tile。
- Decode/cache sizing 只作为性能优化，不能把渲染 bitmap 强制变成 tile aspect ratio。
- 修复覆盖使用 memo 卡片缩略图的 mixed media grids（`MemoMediaGrid`）和 image-only grids（`MemoImageGrid`）。
- 修复覆盖使用 pending image attachment thumbnail 的 `NoteInputSheet` 和 inline compose card。
- 通过聚焦测试防止回退到 exact two-axis thumbnail resizing。
- 在 `evolve_modularity` 阶段，通过集中 aspect-safe sizing 行为，让被触及区域保持同等或更好的结构。

**Non-Goals:**

- 不修改 Memos server `/file/...?...thumbnail=true` 行为或 API compatibility。
- 不修改全屏 image preview/gallery 的 fit 行为。
- 不重设计 memo card grid layout、column count、spacing 或 max visible media count。
- 不重设计 composer attachment strip layout、tile size、remove button 或 pending processing overlay。
- 不新增 image processing dependency。
- 不触碰 private/commercial extension seams。

## Decisions

### Decision 1: 缩略图展示继续使用 `BoxFit.cover`

视觉契约应匹配 issue 诉求：保持原始比例、填满 tile，并裁掉不可见部分。`BoxFit.cover` 是这里正确的 presentation primitive。

备选方案：

- `BoxFit.contain`：可以避免裁切，但会产生 letterboxing，不符合用户诉求。
- 每张图使用 dynamic tile aspect ratio：可以完整显示图片，但会破坏紧凑 memo 卡片网格的稳定性。
- Server-side thumbnail crop：需要假设 server 行为，超出 public Flutter app scope。

### Decision 2: cache/decode sizing 必须 aspect-safe

当已知 source aspect ratio 时，实现不应再把 tile width 和 tile height 当成 exact bitmap shape。memo thumbnail grid 调用方应计算能够保持源图比例、同时满足 cover 需求的 cache target。当 source dimensions 不可用时，安全 fallback 应避免可能造成像素变形的 exact two-axis resize；可以使用 single-axis bound 或省略一个维度。

这对 composer pending attachment 尤其重要：`MemoComposerPendingAttachment` 当前只保存 `filePath`、`filename`、`mimeType` 和 `size` 等提交所需信息，没有 source image `width` / `height`。本变更不应为了缩略图展示把 image metadata 扩散到 composer state；pending thumbnails 应先使用 safe fallback，避免把 62px square preview 变成 exact two-axis decode contract。

备选方案：

- 移除全部 thumbnail cache sizing：视觉上最安全，但滚动列表可能增加内存压力。
- 保留当前 two-axis sizing 并依赖 `BoxFit.cover`：如果底层 decoded image 已经变形，则不足以解决问题。
- 只使用 server thumbnails：不同 server 版本不可靠，也无法覆盖 local files。

### Decision 3: 将 sizing logic 集中到稳定 helper

Aspect-safe cache target calculation 应与 `resolveThumbnailCacheExtent` 一起放在 `core/image_thumbnail_cache.dart` 或相邻 core helper 中。Widget 代码只提供 tile dimensions、device pixel ratio 和 optional source dimensions，然后拿到简单的 cache target object。Composer pending previews 可以复用同一 helper 的 unknown-dimension fallback，而不是在 `note_input_sheet.dart` 和 `memos_list_inline_compose_card.dart` 中各自手写 cache policy。

备选方案：

- 在 `MemoMediaGrid` 和 `MemoImageGrid` 中重复计算：修补最快，但会把 reusable shared display logic 隐藏在 widgets 中，违背 checklist item `4.` 的方向。
- 在 composer widgets 中直接删除 cache hints：视觉上安全，但会让首页和 composer 的 thumbnail policy 分叉，后续容易回退。
- 把逻辑放进 `features/image_preview/widgets/ImagePreviewTile`：会让 generic tile renderer 承担 memo-grid policy，并耦合调用方 layout knowledge。

### Decision 4: 保持 `ImagePreviewTile` generic

`ImagePreviewTile` 应继续根据调用方提供的 `ImagePreviewItem` 和 fit/cache hints 渲染。它可能需要更安全地处理成对 cache dimensions，但 memo-specific source-ratio decisions 应属于 grid/helper layer。

备选方案：

- 给 `ImagePreviewTile` 增加 memo-card-specific flags：增加 API surface，并把 policy 混入 generic preview tile。
- 在 memo grids 中替换为自定义 image widgets：会重复 image source handling 和 error logging。

## Risks / Trade-offs

- [Risk] 部分 remote attachments 可能没有可靠的 `width` / `height` metadata。→ Mitigation: 即使没有 metadata，也使用避免 exact two-axis distortion 的 fallback。
- [Risk] pending composer attachments 当前没有 intrinsic dimensions。→ Mitigation: 不扩散图片宽高到 composer state，先通过 shared helper 使用 unknown-dimension safe fallback。
- [Risk] 减少 exact cache constraints 可能增加超宽/超高图片的 decoded image memory。→ Mitigation: 保留带 `maxDecodePx` 上限的 bounded single-axis 或 aspect-safe cache extents。
- [Risk] 现有测试可能断言 exact `memCacheWidth` 和 `memCacheHeight` forwarding。→ Mitigation: 更新或新增聚焦测试，让测试断言新的 visual/cache contract，而不是旧的 exact-size behavior。
- [Risk] Server-generated thumbnails 可能已经保持比例，也可能随 server version 变化。→ Mitigation: Flutter client 同时对 local files 和 remote images 保持健壮，并避免改变 server/API assumptions。

## Migration Plan

不需要 data migration。

实施顺序：

1. 在 core thumbnail helper 中添加 aspect-safe cache target calculation 和测试。
2. 更新 memo card media grids，让它们从 helper 请求 aspect-safe cache targets。
3. 更新 `NoteInputSheet` 和 inline compose card 的 pending image attachment previews，让 unknown-dimension local images 不再使用 exact two-axis cache sizing。
4. 保持缩略图展示使用 `BoxFit.cover`。
5. 为 square 或 height-limited tiles 中的非方形 source images 增加 widget 或聚焦 unit coverage。
6. 先运行 focused Flutter tests，再在 release 前运行更广泛检查。

Rollback strategy：回退 UI/helper 变更即可；本变更不涉及 persisted data 或 API compatibility。

## Open Questions

- Unknown-dimension remote images 默认 fallback 应偏向 width-only、height-only，还是 no cache bound？设计偏好是保守的 single-axis bound，以平衡内存和视觉安全。
- Pending composer local images 已确认纳入本变更；后续是否把同一 helper 扩展到其它 editor 或 reader thumbnail surfaces，可作为 follow-up。
