## Context

The existing rendering pipeline already has the low-level pieces needed for inline images:

- `MemoMarkdown` can render `<img>` nodes when `renderImages` is true.
- `MemoRenderPipeline` strips Markdown images when `renderImages` is false.
- `collectMemoImageEntries` collects Markdown and HTML image sources for the media grid.
- `MemoInlineImageSourcePolicy` protects local `file:` image rendering by allowlisting only current memo-owned image attachments.
- Clipped/third-party share paths already use inline body rendering and hide duplicate grid images.

The missing behavior is not image rendering itself. It is the decision layer that says an ordinary expanded memo body may render Markdown image syntax inline, while collapsed previews and ordinary raw HTML `<img>` tags remain image-free in the body.

Current ordinary memo behavior:

```text
memo.content
  -> collectMemoImageEntries(content + attachments)
  -> MemoMediaGrid shows image tiles
  -> MemoMarkdown(renderImages: false)
       -> stripMarkdownImages()
       -> body has no image at authored position
```

Target ordinary memo behavior:

```text
memo.content
  -> collapsed card/detail preview:
       MemoMarkdown(renderImages: false)
       MemoMediaGrid shows compact preview tiles

  -> expanded card/detail body:
       MemoMarkdown(renderImages: true, imageSyntax: markdownOnly)
       Markdown ![](...) renders inline
       raw HTML <img> remains disabled for ordinary memos
       trailing MemoMediaGrid excludes inline-rendered images
```

## Goals / Non-Goals

**Goals:**

- Render Markdown image syntax inline in expanded list cards and expanded detail content.
- Keep collapsed previews image-free in the Markdown body.
- Avoid duplicate image display between inline body and trailing media grid.
- Preserve current local `file:` safety: only current memo-owned image attachments may render as local inline images.
- Preserve existing clipped/third-party share HTML image behavior.
- Keep implementation inside `features/memos` without adding new reverse dependencies.

**Non-Goals:**

- Do not render ordinary raw HTML `<img>` tags inline.
- Do not change Markdown storage format or mutate existing memo content.
- Do not change upload/sync/API behavior.
- Do not globally allow arbitrary `file:` URLs.
- Do not redesign the media grid or image preview flow.

## Decisions

### Decision 1: Add an explicit inline image syntax mode

Use an explicit syntax policy instead of treating `renderImages: true` as "render every sanitized image source".

Candidate shape:

```text
MemoInlineImageSyntax.none
MemoInlineImageSyntax.markdownOnly
MemoInlineImageSyntax.markdownAndHtml
```

or the equivalent with booleans such as `renderImages` plus `allowHtmlImages`.

Ordinary expanded memo bodies should use `markdownOnly`. Existing clipped/third-party share bodies can continue using `markdownAndHtml`. Collapsed previews should use `none`.

Rationale:

- The user explicitly wants to allow Markdown image syntax first and avoid accidentally rendering user-authored HTML code.
- A simple `renderImages: true` flip would also preserve raw HTML `<img>` tags after Markdown conversion, which violates the confirmed scope.
- A named syntax mode makes future behavior obvious and testable.

### Decision 2: Strip or neutralize raw HTML images before ordinary Markdown rendering

For `markdownOnly`, the pipeline should keep Markdown image syntax but remove raw HTML `<img>` tags before or during Markdown-to-HTML rendering, with fenced code blocks preserved as code.

Rationale:

- After Markdown conversion, Markdown images and raw HTML images both become `<img>` elements, so post-sanitizer filtering cannot reliably distinguish the source syntax.
- Preprocessing the source before Markdown conversion keeps the distinction clear.

### Decision 3: Reuse the scoped local inline image allowlist

`file:` sources remain blocked unless the URL matches the current memo's image attachment `externalLink` after canonical local path normalization.

Rationale:

- The existing detail/share inline image work already established this safety boundary.
- The new Markdown-only behavior should not allow arbitrary local file reads.

### Decision 4: Share duplicate suppression policy between list and detail

When inline Markdown image rendering is enabled, the trailing media grid should exclude images that are already represented inline. Existing `MemoImageEntry.isAttachment` behavior can likely be reused:

```text
collectMemoImageEntries()
  content Markdown image -> isAttachment=false
  matching attachment duplicate -> skipped by seen-key dedupe

trailing grid during inline body mode:
  images.where(entry.isAttachment)
  + videos
```

If this rule is insufficient for a specific edge case, extract a small helper in `features/memos` so detail and list cards use the same suppression rule.

Rationale:

- Content-authored images should appear at their document position, not again below the article.
- Unreferenced attachments remain useful in the grid.

### Decision 5: Include inline rendering policy in Markdown cache keys

Markdown render cache keys should include the inline image syntax mode and the local allowlist fingerprint when inline rendering is enabled.

Rationale:

- Sanitized HTML depends on whether HTML images are allowed and which local `file:` URLs are allowlisted.
- Without cache-key participation, stale stripped or stale preserved images can be reused after attachment metadata changes.

## Dependency Direction

Before:

```text
features/memos/widgets/memos_list_memo_card.dart
features/memos/memo_detail_screen.dart
  -> local widget decisions
  -> MemoMarkdown(renderImages bool)
  -> duplicate rendering choices split across call sites
```

After:

```text
features/memos/widgets/memos_list_memo_card.dart
features/memos/memo_detail_screen.dart
  -> feature-level inline image rendering policy/helper
  -> MemoMarkdown(image syntax mode + local allowlist)
  -> shared duplicate suppression rule
```

The change stays within `features/memos` and does not introduce `state -> features`, `application -> features`, or `core -> features` dependencies.

## Risks / Trade-offs

- [Risk] Removing raw HTML `<img>` for ordinary expanded memos could surprise users who intentionally used HTML image tags. Mitigation: this is an explicit user-confirmed scope choice; clipped/third-party share HTML image behavior remains unchanged.
- [Risk] The Markdown preprocessor regex may accidentally touch code examples. Mitigation: preserve fenced code blocks and add contract tests with `<img>` inside code fences.
- [Risk] Inline rendering may start more remote image requests after expansion. Mitigation: collapsed previews remain image-free, so scrolling performance should remain close to current behavior.
- [Risk] Duplicate suppression may hide an attachment that was not truly inline if source normalization is too broad. Mitigation: reuse existing collection/dedupe keys and add tests for referenced vs unreferenced attachments.

## Migration Plan

- No data migration.
- Existing memos with Markdown image syntax will render inline in expanded reading surfaces after the code change.
- Existing clipped/third-party share memos continue using their current inline rendering path.
- Rollback only changes rendering behavior; persisted memo content remains compatible.

## Open Questions

- Whether to add the syntax mode as a new enum on `MemoMarkdown` or keep the public widget API smaller with an internal helper plus boolean flags. Implementation should choose the option that creates the least churn while keeping tests clear.
- Whether detail and list should compute the inline policy in their existing resolved-data layers or delegate to a new feature-level helper. Prefer a shared helper if duplicate suppression or cache-key logic would otherwise be repeated.
