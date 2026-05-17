## Why

本地模式下，首页 memo 卡片直接点击图片打开全屏预览时可能显示 broken image；同一张图片进入笔记详情页后再打开却正常。进一步排查发现，第三方剪藏 memo 展开后正文 inline 图片也可能无法显示：这些问题都指向同一类 source freshness 缺口，即 `LocalSync` 已将附件复制到私有附件目录并删除旧的 managed upload source 后，UI 或正文仍可能引用上传前的旧本地路径。

## What Changes

- 让首页 memo 卡片媒体 entry/cache 的 freshness 覆盖附件源变化，而不只依赖 memo content、`updateTime` 和附件数量。
- 确保附件 `externalLink`、`filename`、`type`、`size`、`width`、`height`、`hash` 等影响图片打开源和 decode hint 的字段变化后，首页重新构建 `ImagePreviewItem`。
- 在本地模式 `LocalSync` 处理剪藏 `share_inline_image` 附件时，将 memo 正文中的旧 staged/queued inline image URL 替换为新的 private attachment file URL，避免展开后 `MemoMarkdown` 继续 `Image.file` 已删除路径。
- 保持详情页、全屏 gallery 渲染策略、远程 API adapter 和数据库 schema 不变；本变更只补足本地 source freshness 与正文引用迁移。
- 增加 focused regression test，覆盖本地附件从 queued upload path 迁移到 private attachment path 后，首页 grid tap 使用最新路径打开，并覆盖剪藏 inline `<img src="file://...">` 在展开时不再引用已删除 queued path。
- 在 `evolve_modularity` 阶段，优先把可复用的附件媒体 fingerprint/cache key 和 inline source rewrite 规则放到稳定 helper/service seam，避免继续把 shared source freshness 规则隐藏在 widget build 代码里。

## Capabilities

### New Capabilities
- `memo-media-preview-source-freshness`: 定义 memo media preview 与第三方剪藏 inline image 展示从列表/详情入口渲染时，必须使用当前附件数据中的有效 source，而不能复用已失效的本地路径或过期 URL metadata。

### Modified Capabilities
- None.

## Impact

- 预计影响的 UI/cache 代码：
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_memo_card_container.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_memo_card.dart`
  - `memos_flutter_app/lib/features/memos/memo_media_grid.dart`
  - `memos_flutter_app/lib/features/memos/memo_image_grid.dart`
- 预计影响的本地同步/正文引用代码：
  - `memos_flutter_app/lib/state/sync/local_sync_controller.dart`
  - `memos_flutter_app/lib/features/share/share_inline_image_content.dart`
- 预计影响的测试：
  - `memos_flutter_app/test/features/memos/memos_list_memo_card_container_test.dart`
  - `memos_flutter_app/test/features/memos/memo_image_grid_test.dart`
  - `memos_flutter_app/test/state/sync/...`
  - `memos_flutter_app/test/features/share/share_inline_image_content_test.dart`
- 不计划修改 server API、request/response models、route adapters、sync payload format、database schema 或 commercial/private extension 行为。
- 当前架构阶段为 `evolve_modularity`。本变更触及 modularity checklist `4.`、`7.` 和 `10.`：通过抽取或集中附件 media source fingerprint/cache key 与 inline source rewrite 规则，避免共享 freshness 逻辑继续散落在 widget 文件中；本地 write path 继续由 `LocalSyncController` / mutation seam 负责，并保证 touched area 结构不退化。
