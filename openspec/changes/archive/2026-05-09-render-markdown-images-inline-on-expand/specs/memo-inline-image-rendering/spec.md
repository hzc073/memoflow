## ADDED Requirements

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
