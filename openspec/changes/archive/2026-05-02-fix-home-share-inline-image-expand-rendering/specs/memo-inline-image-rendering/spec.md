## ADDED Requirements

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
