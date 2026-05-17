## ADDED Requirements

### Requirement: Detail local attachment inline images use a scoped file allowlist
The system SHALL render memo detail inline images whose `file:` source is owned by the current memo's image attachments, and SHALL continue to block non-allowlisted local file URLs in memo HTML and Markdown content.

#### Scenario: Current memo private attachment renders inline
- **WHEN** a memo detail page renders expanded third-party share content containing an inline `<img>` whose `src` is the same canonical `file:///...` local path as one of the current memo's image attachment `externalLink` values
- **THEN** the sanitizer preserves the inline image element and the Markdown renderer renders it as a local file image inside the article body

#### Scenario: Unowned local file image remains blocked
- **WHEN** memo content contains an inline `<img src="file:///...">` that does not match any current memo image attachment local source
- **THEN** the sanitizer removes that image and the renderer does not attempt to read the local file

#### Scenario: Canonical local file URL remains file triple slash
- **WHEN** LocalSync finalizes a share inline image and writes both memo content and attachment metadata with `Uri.file(...).toString()`
- **THEN** the detail rendering policy treats `file:///...` as the canonical local file URL form and does not require rewriting it to `file://...`

#### Scenario: Host-mutated file URL is not treated as equivalent
- **WHEN** memo content contains a host-mutated `file://host/path` URL that is not path-equivalent to the current memo attachment `file:///path` URL
- **THEN** the image is not allowlisted as the current memo-owned local attachment source

### Requirement: Detail local inline image rendering avoids duplicate attachment grids
The system SHALL avoid rendering the same current memo image both inline in the article body and again in the detail media grid when the content image and attachment metadata point to the same local file.

#### Scenario: Same local image appears inline only
- **WHEN** a third-party share memo contains an inline image source that matches an image attachment `externalLink`
- **THEN** the detail body renders the image inline and the detail media grid does not include a duplicate tile for the same local file

#### Scenario: Non-inline attachments still render in the media grid
- **WHEN** a memo has image attachments that are not referenced by allowlisted inline image sources in the article body
- **THEN** those image attachments remain eligible for the detail media grid according to the existing media-entry rules

### Requirement: Local inline image allowlist participates in render cache freshness
The system SHALL include local inline image allowlist state or equivalent attachment source metadata in memo detail Markdown render cache keys when inline image rendering is enabled.

#### Scenario: Attachment local source changes without losing render correctness
- **WHEN** a memo's image attachment source metadata changes and the memo detail content is rendered again
- **THEN** the Markdown render cache key changes or otherwise invalidates stale sanitized HTML so the renderer uses the current local inline image policy

#### Scenario: Remote inline image auth behavior is unchanged
- **WHEN** a memo detail page renders relative or same-origin remote Memos file inline images
- **THEN** existing `baseUrl`, `authHeader`, `rebaseAbsoluteFileUrlForV024`, and `attachAuthForSameOriginAbsolute` behavior remains unchanged
