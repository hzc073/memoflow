## MODIFIED Requirements

### Requirement: Full quick clip saves Xiaohongshu media as attachments
The system SHALL save Xiaohongshu media attachments automatically when quick clip is running in full media mode.

#### Scenario: Xiaohongshu image CDN URLs are normalized before discovery
- **WHEN** a Xiaohongshu image/article capture exposes target-note image URLs using `http` on a known Xiaohongshu image CDN host
- **THEN** the parser or cleanup layer SHALL normalize those URLs to `https`
- **AND** parser-level image attachment discovery SHALL use the normalized URLs
