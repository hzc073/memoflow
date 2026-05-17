# memo-inline-image-rendering Specification

## Purpose
TBD - created by archiving change fix-detail-inline-image-auth. Update Purpose after archive.
## Requirements
### Requirement: Detail inline attachment images carry memo auth context
The system SHALL render memo detail Markdown and HTML inline images with the resolved Memos server image request context when the source points to a relative or same-origin Memos file URL.

#### Scenario: Same-origin attachment image in detail content
- **WHEN** a memo detail page renders expanded clipped-article content containing an inline image whose source resolves to the current account's Memos server origin
- **THEN** the Markdown image renderer receives the current `baseUrl`, `authHeader`, `rebaseAbsoluteFileUrlForV024`, and `attachAuthForSameOriginAbsolute` context needed to attach the `Authorization` header

#### Scenario: Relative attachment image in detail content
- **WHEN** a memo detail page renders expanded clipped-article content containing an inline image with a relative `/file/attachments/...` source
- **THEN** the Markdown image renderer receives the current `baseUrl` and `authHeader` context needed to resolve the URL and attach the `Authorization` header

#### Scenario: Collapsed detail content does not start inline image requests
- **WHEN** memo detail content is displayed in the collapsed state
- **THEN** inline image rendering remains disabled for the collapsed preview and no remote image request is started by the collapsed Markdown content

### Requirement: Detail auth propagation is regression-tested
The system SHALL include focused automated coverage for the memo detail `contentOverride` rendering path so Markdown image authorization context is not dropped by wrapper widgets.

#### Scenario: Detail wrapper passes auth context to MemoMarkdown
- **WHEN** `MemoDocumentPrimaryContent` builds its `_CollapsibleText` content override from `MemoDocumentResolvedData` that contains `baseUrl`, `authHeader`, and server-version image flags
- **THEN** the descendant `MemoMarkdown` receives the same image request context values

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

### Requirement: Home expanded cards use scoped local inline image allowlists
The system SHALL render home/list memo card expanded article inline images whose `file:` source is owned by the current memo's image attachments, and SHALL continue to block non-allowlisted local file URLs in expanded card Markdown and HTML content.

#### Scenario: Expanded card renders current memo private attachment inline
- **WHEN** a home/list memo card is expanded for third-party share article content containing an inline image whose `src` is the same canonical `file:///...` local path as one of the current memo's image attachment `externalLink` values
- **THEN** the expanded card Markdown renderer preserves the inline image element and renders it as a local file image inside the article body

#### Scenario: Expanded card blocks unowned local file image
- **WHEN** a home/list memo card is expanded for content containing an inline `<img src="file:///...">` that does not match any current memo image attachment local source
- **THEN** the sanitizer removes that image and the card renderer does not attempt to read the unowned local file

#### Scenario: Collapsed card preview remains image-free
- **WHEN** a home/list memo card is shown in its collapsed preview state
- **THEN** inline image rendering remains disabled and the collapsed Markdown content does not start local file or remote image requests

#### Scenario: Expanded inline image opens preview with local source
- **WHEN** a user taps an allowlisted local inline image rendered inside an expanded home/list card article body
- **THEN** the shared image preview flow opens with an `ImagePreviewItem` whose source resolves to the current private local file

### Requirement: Home expanded card local inline policy participates in render cache freshness
The system SHALL include local inline image allowlist state or equivalent attachment source metadata in home/list expanded card Markdown render cache keys when inline image rendering is enabled.

#### Scenario: Attachment local source change invalidates expanded card markdown cache
- **WHEN** a memo's image attachment source metadata changes and the home/list expanded card content is rendered again with inline image rendering enabled
- **THEN** the Markdown render cache key changes or otherwise invalidates stale sanitized HTML so the renderer applies the current local inline image policy

#### Scenario: Remote inline image behavior remains unchanged
- **WHEN** a home/list expanded card renders relative or same-origin remote Memos file inline images
- **THEN** existing `baseUrl`, `authHeader`, `rebaseAbsoluteFileUrlForV024`, and `attachAuthForSameOriginAbsolute` behavior remains unchanged

### Requirement: Expanded ordinary memo bodies render Markdown image syntax inline
The system SHALL render Markdown image syntax inline at its authored document position when an ordinary memo body is expanded in list or detail reading surfaces.

#### Scenario: Expanded list card renders Markdown image inline
- **GIVEN** an ordinary memo contains Markdown image syntax `![](https://example.com/a.png)`
- **WHEN** the home/list memo card is expanded
- **THEN** the expanded card body renders that image at the Markdown image position
- **AND** the collapsed card body remains image-free before expansion

#### Scenario: Expanded detail body renders Markdown image inline
- **GIVEN** an ordinary memo contains Markdown image syntax `![](https://example.com/a.png)`
- **WHEN** the memo detail body is expanded or starts in an expanded body state
- **THEN** the detail body renders that image at the Markdown image position

#### Scenario: Collapsed detail content does not start Markdown image requests
- **GIVEN** an ordinary memo contains Markdown image syntax `![](https://example.com/a.png)`
- **WHEN** memo detail content is displayed in the collapsed state
- **THEN** inline image rendering remains disabled for the collapsed Markdown content
- **AND** the collapsed Markdown content does not start remote or local image requests

### Requirement: Ordinary memo inline rendering is Markdown-only
The system SHALL NOT render raw HTML `<img>` tags inline for ordinary memo content when enabling expanded Markdown image rendering.

#### Scenario: Ordinary expanded list card ignores raw HTML image tags
- **GIVEN** an ordinary memo contains raw HTML `<img src="https://example.com/a.png">`
- **WHEN** the home/list memo card is expanded
- **THEN** the expanded ordinary memo body does not render that raw HTML image tag inline

#### Scenario: Ordinary expanded detail body ignores raw HTML image tags
- **GIVEN** an ordinary memo contains raw HTML `<img src="https://example.com/a.png">`
- **WHEN** the memo detail body is expanded
- **THEN** the expanded ordinary memo body does not render that raw HTML image tag inline

#### Scenario: Existing clipped article HTML image behavior remains unchanged
- **GIVEN** a clipped or third-party share memo uses the existing clipped-article inline rendering path
- **WHEN** that clipped article body is expanded
- **THEN** existing allowed HTML image rendering behavior remains available according to the pre-existing clipped-article rules

#### Scenario: HTML image examples inside fenced code remain code
- **GIVEN** memo content contains `<img src="https://example.com/a.png">` inside a fenced code block
- **WHEN** the memo body is rendered in ordinary Markdown-only inline image mode
- **THEN** the fenced code block remains code content
- **AND** the HTML image example does not start an image request

### Requirement: Expanded inline Markdown images avoid duplicate media grid tiles
The system SHALL avoid rendering the same image both inline in the expanded memo body and again in the trailing media grid.

#### Scenario: Markdown content image appears inline only after expansion
- **GIVEN** an ordinary memo contains Markdown image syntax `![](https://example.com/a.png)`
- **WHEN** the memo body is expanded and the Markdown image renders inline
- **THEN** the trailing media grid does not include a duplicate tile for `https://example.com/a.png`

#### Scenario: Referenced image attachment appears inline only after expansion
- **GIVEN** an ordinary memo contains Markdown image syntax pointing to the same image source as one of the current memo's image attachments
- **WHEN** the memo body is expanded and the Markdown image renders inline
- **THEN** the trailing media grid does not include a duplicate tile for that referenced image attachment

#### Scenario: Unreferenced attachments remain in trailing media grid
- **GIVEN** an ordinary memo contains one Markdown image and also has an image attachment that is not referenced by the Markdown content
- **WHEN** the memo body is expanded
- **THEN** the Markdown image renders inline
- **AND** the unreferenced image attachment remains eligible for the trailing media grid

#### Scenario: Videos remain in trailing media grid
- **GIVEN** an ordinary memo contains Markdown image syntax and has a video attachment
- **WHEN** the memo body is expanded
- **THEN** the Markdown image renders inline
- **AND** the video attachment remains eligible for the trailing media grid

### Requirement: Markdown local file images use scoped memo ownership
The system SHALL render Markdown `file:` inline images only when the local file source is owned by the current memo's image attachments.

#### Scenario: Memo-owned local Markdown image renders inline
- **GIVEN** an ordinary memo contains Markdown image syntax whose URL is a canonical `file:///...` URL
- **AND** the current memo has an image attachment whose `externalLink` resolves to the same local file path
- **WHEN** the memo body is expanded
- **THEN** the sanitizer preserves the image source
- **AND** the image renders inline from the local file

#### Scenario: Unowned local Markdown image remains blocked
- **GIVEN** an ordinary memo contains Markdown image syntax whose URL is a `file:` URL
- **AND** no current memo image attachment owns that local file source
- **WHEN** the memo body is expanded
- **THEN** the sanitizer removes or neutralizes that image source
- **AND** the renderer does not attempt to read that local file

#### Scenario: Remote Markdown image request context is preserved
- **GIVEN** an ordinary memo contains Markdown image syntax pointing to a relative or same-origin Memos file URL
- **WHEN** the memo body is expanded
- **THEN** the Markdown image renderer receives the current `baseUrl`, `authHeader`, `rebaseAbsoluteFileUrlForV024`, and `attachAuthForSameOriginAbsolute` context needed to resolve the URL and attach authorization when required

### Requirement: Inline Markdown image policy participates in render cache freshness
The system SHALL include inline image syntax mode and local inline image allowlist state, or equivalent source metadata, in Markdown render cache keys when expanded inline Markdown image rendering is enabled.

#### Scenario: Syntax mode change invalidates sanitized Markdown output
- **WHEN** the same memo content is rendered first with inline images disabled and later with ordinary Markdown-only inline image rendering enabled
- **THEN** the Markdown render cache key changes or otherwise avoids reusing stale image-stripped output

#### Scenario: Local allowlist change invalidates sanitized Markdown output
- **WHEN** a memo's image attachment source metadata changes and the memo content is rendered again with inline Markdown image rendering enabled
- **THEN** the Markdown render cache key changes or otherwise avoids reusing stale sanitized output from the previous local inline image policy

