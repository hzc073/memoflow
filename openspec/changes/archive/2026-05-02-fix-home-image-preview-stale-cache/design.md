## Context

本地模式创建带图片附件的 memo 时，UI 会先使用 placeholder attachment 或剪藏 inline image URL 构建可见内容。其 source 通常指向 `queued_attachment_uploads/...` managed upload source。随后 `LocalSync` 会 preprocess 图片、复制到 local library private attachment path、更新 `attachments_json.externalLink`，并删除 managed upload source。

目前存在两条 stale source 暴露路径：

```text
Path A: home/list media grid
placeholder attachment.externalLink
  -> MemoImageEntry.localFile
  -> _memoMediaEntriesCache
  -> ImagePreviewOpenRequest
```

首页 memo card container 的 `_memoMediaEntriesCache` key 只覆盖 memo identity、content fingerprint、`updateTime`、附件数量和账号 URL/auth flags，没有覆盖附件 source metadata。由于 `updateMemoAttachmentsJson` 不更新 memo `updateTime`，首页可能命中旧 cache，并把已删除的 queued path 传给全屏 image preview。

```text
Path B: third-party clip inline image
memo.content <img src="file:///.../queued_attachment_uploads/...">
  -> MemoMarkdown
  -> Image.file(old queued path)
```

剪藏正文只有展开时才渲染 inline images；折叠时 `renderImages` 被关闭，因此问题在“展开后”暴露。`MemoMarkdown` 遇到 `file://` 会直接渲染 `Image.file`，不会根据 attachment metadata 反查当前 private path。如果 `LocalSync` 更新了 attachment `externalLink` 但没有同步替换 memo content 中的 inline `file://`，展开后仍会引用已删除路径。

当前架构阶段为 `evolve_modularity`。本变更触及 memo UI/cache 与本地同步 write path；修复应保持在 feature/helper seam 与 `LocalSyncController` 现有 owner 内，不引入新的 `state -> features`、`application -> features` 或 `core -> features` 依赖。

## Goals / Non-Goals

**Goals:**
- 首页 memo card media cache MUST 在附件 source metadata 改变后失效。
- 列表/首页打开图片 preview MUST 使用当前 memo attachments 中的有效 `externalLink` / local file path。
- 本地模式 `LocalSync` 处理剪藏 `share_inline_image` 附件后，memo content 中的 staged/queued inline image URL MUST 被迁移到 private attachment file URL。
- 展开第三方剪藏 memo 时，`MemoMarkdown` MUST NOT 继续渲染已删除的 queued upload path。
- 添加回归测试，复现 queued path 被删除但 attachments 更新为 private path 后，首页点击和剪藏正文展开都使用最新 path。
- 将 media source freshness 与 inline source rewrite 规则集中到可复用 helper/service seam，减少 widget build 内隐藏的共享规则，满足 `evolve_modularity` 下 checklist `4.` / `7.` / `10.`。

**Non-Goals:**
- 不改变 image preview gallery 的 progressive/direct rendering 策略。
- 不修改 server API、request/response model、route adapter、database schema 或 remote sync payload format。
- 不改变远程同步已存在的 inline image remote URL rewrite 语义。
- 不处理任意历史损坏路径的通用恢复 UX；本变更聚焦 LocalSync 可确定的新旧 source 迁移。
- 不改变剪藏文章是否默认展开、折叠阈值或 markdown/html sanitizer 行为。

## Decisions

### Decision 1: Use attachment media fingerprint in the home media cache key

在 `_memoMediaEntriesCacheKey` 中加入一个稳定的 attachment media fingerprint。fingerprint 至少覆盖：

- `attachment.name`
- `attachment.filename`
- `attachment.type`
- `attachment.size`
- `attachment.externalLink`
- `attachment.width`
- `attachment.height`
- `attachment.hash`

这样 `LocalSync` 只更新 `attachments_json`、不更新 `updateTime` 时，首页 card 也能感知 attachment source/metadata 变化并重建 `MemoImageEntry`。

**Alternatives considered:**
- 删除 `_memoMediaEntriesCache`：最简单但可能增加列表滚动时的 markdown image extraction 与 attachment mapping 成本。
- 让 `updateMemoAttachmentsJson` 更新 `updateTime`：语义更重，会把附件落盘元数据变化伪装成用户可见 memo 更新时间变化，也可能影响排序和同步语义。
- 在 gallery 中 fallback 到 URL：当前 stale item 往往没有 URL，且 gallery 层无法知道最新 memo attachments；修复点太晚。

### Decision 2: Rewrite local share-inline content during LocalSync upload finalization

在本地模式 `_handleUploadAttachment` 中，当 upload payload 标记 `share_inline_image == true` 且包含 `share_inline_local_url` 时，使用当前已知 source mapping：

```text
old inline URL:
  payload.share_inline_local_url
  或 Uri.file(payload.file_path)

new inline URL:
  Uri.file(privatePath)
```

在 `_upsertAttachment` 写入 private attachment 后、删除 managed upload source 前，将 memo content 中匹配的旧 inline image URL 替换为 private attachment URL，并写回 memo/local library。这样 `MemoMarkdown` 展开时仍可直接 `Image.file`，但 source 已经是存在的 private path。

**Alternatives considered:**
- 在 `MemoMarkdown` 渲染期查 attachment metadata 并替换 `file://`：会把同步/存储一致性问题推给 UI，且 markdown renderer 缺少完整 memo attachment mutation context。
- 不替换 content，只保留 managed upload source：会留下临时文件生命周期问题，和现有 cleanup 设计冲突。
- 只依赖 attachment grid 展示剪藏图：剪藏正文 inline image 是文章阅读体验的一部分，不能只修复附件 grid。

### Decision 3: Keep source freshness logic in scoped seams

实现时优先使用两个小 seam：

```text
features/memos/<media cache helper>
  -> builds attachment preview/source fingerprint

features/share/share_inline_image_content.dart 或 state/sync local helper
  -> rewrites known old inline local URLs to current local file URLs
```

依赖方向保持：

```text
Before:
features/memos/widgets/memos_list_memo_card_container.dart
  -> inline cache key string assembly

state/sync/local_sync_controller.dart
  -> updates attachment externalLink
  -> deletes managed source
  -> does not migrate memo.content inline source

After:
features/memos/widgets/memos_list_memo_card_container.dart
  -> features/memos/<helper seam>
       -> data/models/attachment.dart

state/sync/local_sync_controller.dart
  -> existing local sync write owner
  -> share inline URL rewrite helper
```

不新增 lower-layer reverse dependencies。`LocalSyncController` 已经是本地同步 write path owner；本变更只是让它在同一次 source migration 中维护 memo content 与 attachment metadata 一致。

### Decision 4: Test both stale-source surfaces

测试需要覆盖两个可观察行为：

1. home/list cache：同一 memo identity、相同 `updateTime`、相同附件数量，但不同 `externalLink` 的两次 build；第二次旧 path 不存在、新 path 存在。tap 后 preview request 或 tile source 使用新 path。
2. clip inline image：本地 sync 处理 `share_inline_image` upload 后，memo content 中不再包含 queued/staged inline URL，而包含 private attachment file URL；删除旧 source 后展开 markdown 不会引用旧 path。

纯 helper tests 负责锁定 fingerprint/rewrite 函数；widget/state tests 负责锁定端到端行为。

## Risks / Trade-offs

- [Risk] fingerprint 覆盖字段过少，未来其他影响 preview source 的字段变化仍可能 stale → Mitigation: 覆盖 source、identity、decode metadata 和 content metadata 字段，并通过 helper test 锁定。
- [Risk] fingerprint 字符串过长影响列表性能 → Mitigation: 只对 attachments 做线性拼接/哈希，memo 卡片附件数量通常有限；保留 LRU cache 的整体收益。
- [Risk] inline rewrite 漏掉 HTML escaped URL 或 markdown angle-bracket URL 变体 → Mitigation: 复用/扩展 `replaceShareInlineImageUrl` 的 URL variants，并添加 HTML + markdown 两类测试。
- [Risk] 替换 memo content 可能影响 sync state 或 outbox 语义 → Mitigation: 在 LocalSync 当前 upload finalization write path 内完成，避免新增远程 payload 语义；测试确认本地模式不新增 API/schema 依赖。
- [Risk] 与正在进行的 `fix-memo-thumbnail-aspect-crop` 改动同时触碰 image grid/cache helper → Mitigation: 本变更限定为 source freshness，不修改 aspect-safe thumbnail sizing 行为；实现时注意 rebase/合并测试覆盖。

## Migration Plan

- 无 schema/data migration。
- 发布后，已有 stale in-memory cache 会在 app 重启后自然消失；代码变更后新的 build 会基于附件 fingerprint 正确失效。
- 对已存在的旧剪藏 memo，如果 content 已经持有被删除的 queued path 且没有可确定 mapping，本变更不做批量修复；后续可另开 repair/backfill change。
- 如需回滚，可移除 cache fingerprint 调整与 LocalSync inline rewrite 调用；不影响持久化 schema。

## Open Questions

- media fingerprint helper 是否放在 `memo_image_grid.dart` 附近，还是新建 `memo_media_cache_key.dart` 更清晰？实现时应优先选择不会扩大 public API 面的最小 seam。
- inline URL rewrite helper 是否直接复用 `features/share/share_inline_image_content.dart`，还是在 `state/sync` 增加 local-only wrapper 以避免扩大 feature import？实现时需要检查现有 `state/sync` import 边界。
- 现有测试 harness 是否能直接观察 `ImagePreviewOpenRequest`，还是需要通过 `ImagePreviewTile` / `FileImage` source 间接断言？实现阶段根据现有 test utilities 决定。
