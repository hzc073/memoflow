## Context

已有两个相邻修复奠定了本次变更的边界：

- `fix-home-image-preview-stale-cache` 已让 `LocalSync` 在处理 `share_inline_image` upload 后，把 memo content 中的 queued/staged local URL 迁移到 private attachment file URL，并让 home/list media cache 关注 attachment source metadata。
- `fix-local-share-inline-image-detail-rendering` 已为 detail/reader path 引入 `MemoInlineImageSourcePolicy`，只允许“当前 memo image attachment 拥有的 `file:` URL”穿过 HTML sanitizer。

当前漏点在 home/list memo card expanded article body：`MemoMarkdown(renderImages: true)` 会在展开剪藏正文时运行，但该路径没有传入 `allowedLocalImageUrls`。因此同步成功后，正文中的 `file:///.../local_attachments/...` 图片仍可能被 sanitizer 移除；同时 expanded clipped-article 状态会隐藏 media grid，用户看到的是“展开后没有图片/无法点开图片”。

Dependency direction before:

```text
features/memos/widgets/memos_list_memo_card.dart
  -> MemoMarkdown
  -> no local inline allowlist
  -> sanitizer blocks file:
```

Dependency direction after:

```text
features/memos/widgets/memos_list_memo_card.dart
  -> memo_inline_image_sources.dart
  -> MemoMarkdown(allowedLocalImageUrls)
  -> sanitizer allows only current memo-owned file:
```

The change stays inside `features/memos` and does not add `state -> features`, `application -> features`, or `core -> features` dependencies.

## Goals / Non-Goals

**Goals:**

- Render local-mode third-party clipped inline images inside home/list expanded card bodies after `LocalSync` rewrites them to private attachment `file:` URLs.
- Keep the same scoped ownership rule used by detail/reader paths: only current memo image attachments may allowlist local file URLs.
- Keep collapsed home/list previews from starting inline image loads.
- Include the local inline image policy fingerprint in the expanded card Markdown cache key so stale sanitized artifacts are not reused.
- Add regression coverage for the home/list expanded card path.

**Non-Goals:**

- No changes to `LocalSync` upload ordering, attachment payload schema, or local library file layout.
- No global allowance for arbitrary `file:` URLs.
- No changes to remote Memos file URL auth/rebase behavior.
- No changes to image compression, WebP passthrough, image-bed upload behavior, or App Store/private extension hooks.

## Decisions

### Decision 1: Reuse `MemoInlineImageSourcePolicy` for the home/list card

The card path should call the existing policy builder with `content: memo.content` and `attachments: memo.attachments`, then pass `policy.allowedLocalImageUrls` to `MemoMarkdown` only when expanded article body rendering is enabled.

Rationale:

- This keeps local file ownership rules centralized instead of duplicating sanitizer logic in card widgets.
- Detail, reader, and card paths will share the same canonical `file:///...` behavior.
- It preserves the security boundary: `file:` image rendering remains scoped to current memo-owned image attachments.

Alternatives considered:

- Allow all `file:` URLs in home card markdown. Rejected because it weakens sanitizer behavior and diverges from detail safety.
- Keep relying on media grid fallback. Rejected because expanded clipped-article cards intentionally hide the grid to avoid duplicate reading experiences.

### Decision 2: Keep collapsed previews image-free

Collapsed card content should continue to call `MemoMarkdown` with `renderImages: false`; the allowlist is only meaningful for expanded article bodies where `renderImages` is true.

Rationale:

- This preserves current performance and avoids starting local file image reads while scrolling the list.
- It matches existing behavior where clipped article images only become part of the article body after expansion.

Alternatives considered:

- Render inline images in all card states. Rejected because it changes list density, scroll performance, and existing card preview semantics.

### Decision 3: Add local inline fingerprint to the card Markdown cache key

When `renderExpandedArticleBody` is true, the card markdown cache key should include `MemoInlineImageSourcePolicy.fingerprint` or an equivalent attachment source fingerprint.

Rationale:

- Sanitized HTML depends on the allowlist. If attachment `externalLink` changes while content text is otherwise stable, a cache key that only sees content can reuse a stale sanitized artifact.
- This mirrors the detail path, which already includes `localInlineImageFingerprint`.

Alternatives considered:

- Disable markdown caching for expanded article bodies. Rejected as unnecessarily broad and slower.
- Rely only on `memoMediaEntriesCacheKey`. Rejected because media grid cache and markdown sanitizer cache are separate concerns.

### Decision 4: Guard with focused feature tests

Add widget/contract tests that exercise the exact card expansion path instead of relying only on lower-level sanitizer tests.

Rationale:

- The bug exists because lower-level behavior was correct but one wrapper path did not propagate policy.
- A focused card test acts as a guardrail against future wrapper drift without adding architecture-level dependencies.

## Risks / Trade-offs

- [Risk] The card widget gains another feature-level helper dependency within `features/memos` -> Mitigation: keep dependency horizontal inside the same feature and avoid lower-layer imports from `state`, `application`, or `core`.
- [Risk] Cache-key churn could cause extra markdown rebuilds -> Mitigation: include only the compact policy fingerprint and only for expanded inline-image rendering.
- [Risk] Tests may need to simulate local files or image decoding -> Mitigation: prefer assertions on sanitizer output / `MemoMarkdown` request plumbing where possible, and use tiny temp files only when widget image rendering must be observed.
- [Risk] Existing `fix-memo-thumbnail-aspect-crop` may touch media/grid code nearby -> Mitigation: keep this change scoped to inline body rendering and cache key propagation, not thumbnail sizing.

## Migration Plan

- No schema or data migration.
- Existing synced memos already containing private `file:///.../local_attachments/...` inline URLs will render once the new card path passes the allowlist.
- Rollback is straightforward: remove the card allowlist propagation and cache-key fingerprint addition; persisted data remains compatible.

## Open Questions

- Should the home/list card compute `MemoInlineImageSourcePolicy` internally, or should `MemosListMemoCardContainer` compute and pass it down? Default implementation should choose the smaller public surface; computing inside the card is acceptable because it already owns the `MemoMarkdown` call and receives `memo`.
- Is there an existing `memos_list_memo_card_test.dart` harness that can tap the expand button and inspect `MemoMarkdown`, or should coverage be added adjacent to existing card/container tests? Implementation should prefer the nearest existing harness.
