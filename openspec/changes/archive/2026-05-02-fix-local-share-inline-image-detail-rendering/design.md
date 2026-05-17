## Context

Local share clipping produces article body content that may contain inline HTML such as:

```html
<img src="file:///data/user/0/com.memoflow.../files/local_attachments/<memoUid>/<image>.jpg" width="100%">
```

That URL shape is correct. `file:///data/...` means:

```text
scheme = file
host   = empty
path   = /data/user/0/...
```

Changing it to `file://data/...` changes the URI meaning:

```text
scheme = file
host   = data
path   = /user/0/...
```

So the stable fix must keep `Uri.file(...).toString()` / `file:///...` as canonical, and make the detail render pipeline understand only safe memo-owned local inline image URLs.

Current relevant flow:

```text
LocalSync upload finalization
  -> copies processed image to LocalAttachmentStore local_attachments/<memoUid>/
  -> updates Attachment.externalLink = Uri.file(privatePath).toString()
  -> rewrites share inline <img src> to the same private file URL

Memo detail
  -> buildMemoDocumentResolvedData()
  -> effectiveRenderInlineImages = contentHasThirdPartyShareMarker(memo.content)
  -> MemoRenderPipeline.build(renderImages: true)
  -> sanitizeMemoHtml()
  -> current sanitizer blocks file: img src
  -> MemoMarkdown never receives the local image widget
```

Attachment grids already render local files through `Attachment.externalLink` -> `MemoImageEntry.localFile`. The missing piece is not local file decoding; it is a scoped sanitizer/rendering policy for inline local images.

## Goals / Non-Goals

**Goals:**

- Render local share-clipped inline images in memo detail when the `file:` URL belongs to the current memo's image attachments.
- Preserve `file:///` as the canonical local file URL and avoid accepting malformed `file://host/path` variants as a workaround.
- Keep arbitrary local file reads blocked in memo HTML/Markdown content.
- Avoid duplicate rendering when the same image exists both as inline content and attachment metadata.
- Keep existing remote image auth propagation behavior unchanged.
- Add regression coverage around sanitizer allowlisting, render-pipeline output, detail resolved data, and grid duplicate suppression.
- Improve modularity by centralizing local inline image ownership/allowlist decisions in a reusable feature-level seam.

**Non-Goals:**

- No schema migration.
- No API route, request/response model, or server version compatibility changes.
- No broad WebView or platform permission changes.
- No change to remote sync payload format.
- No attempt to repair historical memos whose content points at a deleted queued upload path and no longer has a recoverable attachment mapping.
- No global support for arbitrary `file:` images in user-authored memo content.

## Decisions

### Decision 1: Use a memo-owned local image allowlist, not a global `file:` exception

The sanitizer should allow `file:` only for `img[src]` values that are explicitly recognized as current memo-owned local inline image sources.

Recommended seam:

```text
features/memos/memo_inline_image_sources.dart
```

Responsibilities:

- Read current memo content and image attachments.
- Extract inline image URLs using existing memo image extraction behavior.
- Resolve image attachment local file URLs from `Attachment.externalLink`.
- Compare local file sources by canonical local file path, not by naive string prefix.
- Return a small immutable policy/fingerprint shape, for example:

```text
MemoInlineImageSourcePolicy
  allowedLocalImageUrls: Set<String>
  fingerprint: String
```

The allowlist should be derived from intersection-like ownership:

```text
content inline file URL
        │
        ▼ normalized local path
memo image attachment externalLink
        │
        ▼ normalized local path
match? yes -> allow original/canonical inline URL
match? no  -> block
```

This keeps the trust boundary narrow:

```text
Allowed:
  <img src="file:///.../local_attachments/memoA/photo.jpg">
  AND memo.attachments contains image externalLink to the same local path

Blocked:
  <img src="file:///sdcard/secret.jpg">
  with no matching current memo image attachment

Blocked:
  <img src="file://data/user/0/...">
  because this is not path-equivalent to canonical file:///data/...
```

Alternative considered: allow all `file:` images in `sanitizeMemoHtml`. Rejected because memo content is user-controlled and desktop builds can access broad filesystem paths. It also weakens the current sanitizer contract unnecessarily.

Alternative considered: special-case `local_attachments` string in the sanitizer. Rejected because sanitizer should not hard-code storage layout strings or app support paths; ownership belongs closer to memo/attachment rendering context.

### Decision 2: Thread the allowlist through the render pipeline

Proposed data flow:

```text
buildMemoDocumentResolvedData()
  -> buildMemoInlineImageSourcePolicy(memo.content, memo.attachments)
  -> buildMemoRenderArtifact(
       renderImages: effectiveRenderInlineImages,
       allowedLocalImageUrls: policy.allowedLocalImageUrls,
       cacheKey: detail cache key + policy.fingerprint
     )
  -> _CollapsibleText
  -> MemoMarkdown(allowedLocalImageUrls: policy.allowedLocalImageUrls)
  -> MemoRenderPipeline.build(...)
  -> sanitizeMemoHtml(..., allowedLocalImageUrls: ...)
```

`MemoReaderContent` should use the same policy when it renders content directly without a `contentOverride`, so reader surfaces and detail surfaces do not drift.

`MemoMarkdown` already knows how to render local files once the sanitized HTML contains an `img` tag with `scheme == file`. The change should make sanitizer output safe local image tags; it should not add another local image renderer.

Alternative considered: bypass sanitizer for detail clipped articles. Rejected because clipped HTML can contain arbitrary tags/attributes; sanitizer remains the correct security boundary.

### Decision 3: Extend sanitizer API with a narrow option

Recommended signature shape:

```text
sanitizeMemoHtml(String html, {Set<String> allowedLocalImageUrls = const {}})
MemoRenderPipeline.build(..., Set<String> allowedLocalImageUrls = const {})
MemoMarkdown(..., Set<String> allowedLocalImageUrls = const {})
```

Rules:

- `a[href="file:///..."]` remains blocked.
- `img[src="file:///..."]` is preserved only when the source is in `allowedLocalImageUrls`.
- `http` and `https` behavior remains unchanged.
- Relative image URLs remain unchanged and continue to resolve through existing `baseUrl` / auth behavior.
- Unsafe schemes such as `javascript:`, `data:`, and unrelated custom schemes remain blocked in memo content.

The comparison should happen on parsed/canonicalized URL values produced before sanitization. If a helper chooses to compare by local path, it should still pass the exact safe source strings that the sanitizer may preserve.

### Decision 4: Include local-inline policy freshness in Markdown cache keys

Current detail cache key includes memo identity, content fingerprint, `renderImages`, and clip-title behavior. This is not enough once sanitizer output depends on attachment-derived allowlist state.

Add the policy fingerprint, or reuse the existing media attachment source fingerprint, so a memo whose attachment `externalLink` changes from queued/private/missing path does not keep stale sanitized HTML.

Recommended cache shape:

```text
detail|<uid>|<contentFingerprint>|renderImages=1|clip=1|localInline=<policyFingerprint>|...
reader|<uid>|<contentFingerprint>|...|localInline=<policyFingerprint>
```

Alternative considered: rely only on content fingerprint. Rejected because the allowlist is derived from attachments too, and attachment metadata can change without content changing in future sync/import flows.

### Decision 5: Let existing media-entry de-duplication suppress duplicate grids

`collectMemoImageEntries` already processes content images first, then attachment images, and skips entries with the same local file path / URL key. When LocalSync has rewritten content and attachment metadata to the same `file:///...` private URL, this naturally yields one content inline entry and no duplicate attachment image entry.

The implementation should preserve that behavior and add tests proving:

```text
content <img src=file:///private/photo.jpg>
attachment.externalLink = file:///private/photo.jpg
        │
        ▼
imageEntries contains inline item only
mediaEntries for renderInlineImages contains no duplicate image tile
```

If duplicate behavior appears, prefer tightening the shared source comparison/dedup seam over adding ad-hoc detail-widget filtering.

### Decision 6: Preserve dependency direction

Before:

```text
features/memos/detail widgets
  -> memo_render_pipeline
  -> memo_html_sanitizer
  -> memo_image_grid extraction helpers
```

After:

```text
features/memos/detail widgets
  -> memo_inline_image_sources seam
  -> memo_render_pipeline
  -> memo_html_sanitizer
```

No new `state -> features`, `application -> features`, or `core -> features` dependency should be introduced. The new policy seam stays under `features/memos` because it combines UI rendering semantics with `Attachment` metadata already used by memo feature rendering.

This touches the `evolve_modularity` hotspot where reusable memo document logic currently lives near `memo_detail_screen.dart`. The scoped improvement is to avoid burying local inline ownership rules inside `_CollapsibleText`, `MemoReaderContent`, or sanitizer branches.

## Risks / Trade-offs

- [Risk] Allowing `file:` too broadly could expose local filesystem paths in rendered memo content. → Mitigation: require current memo image attachment ownership and keep all non-allowlisted `file:` URLs blocked.
- [Risk] Path equivalence can differ by platform, especially Windows case sensitivity and Android paths. → Mitigation: use `Uri.parse(...).toFilePath()` / `Uri.file(path).toString()` canonicalization and apply platform-aware path normalization similar to image preview matching.
- [Risk] Cache keys may continue to reuse HTML where `file:` images were stripped. → Mitigation: add local-inline policy or attachment-source fingerprint to Markdown cache keys and cover source metadata changes in tests.
- [Risk] Inline and attachment gallery entries can duplicate if URL strings differ while paths match. → Mitigation: compare local sources by normalized local file path in the policy/dedup helper, not only raw URL text.
- [Risk] Existing tests may assert `sanitizeMemoHtml` blocks all `file:` URLs. → Mitigation: keep default behavior unchanged; only allow explicit `allowedLocalImageUrls`.
- [Risk] Introducing the allowlist directly in widget code would make future render paths diverge. → Mitigation: centralize the rule in a helper and thread the policy through render surfaces.

## Migration Plan

- No database migration.
- Existing memos whose content already references valid private local attachment URLs will render inline after the code change, as long as their attachment metadata still points to the same local file.
- Existing memos whose content references deleted queued upload paths remain unrecoverable without a separate backfill/repair change.
- Rollback is straightforward: remove the allowlist threading and sanitizer option; memo content and attachment metadata are unchanged.

## Open Questions

- Should the initial allowlist accept any current image attachment `file:` source, or require that the content URL and attachment URL are path-equivalent before adding it? The safer default is path-equivalent intersection.
- Should the policy fingerprint reuse `memoMediaAttachmentSourceFingerprint` directly, or define a narrower fingerprint over only allowed local inline image URLs? The narrower fingerprint reduces unrelated cache churn; the shared media fingerprint reduces duplicate helper logic.
- Should renderer tests assert actual `Image.file` widget creation, or stop at sanitized HTML/`MemoMarkdown` configuration? A small widget test is valuable, but pipeline-level tests should carry most of the contract.
