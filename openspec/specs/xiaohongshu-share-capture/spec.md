# xiaohongshu-share-capture Specification

## Purpose
TBD - created by archiving change fix-xiaohongshu-share-deeplink-capture. Update Purpose after archive.
## Requirements
### Requirement: Xiaohongshu deep links become video capture results
The system SHALL detect Xiaohongshu `xhsdiscover://video_feed/...` deep links encountered during third-party share capture and convert valid video preload payloads into video capture results.

#### Scenario: Valid video preload payload is parsed
- **WHEN** a Xiaohongshu share page attempts main-frame navigation to `xhsdiscover://video_feed/<noteId>` with `h5VideoPreloadInfo` containing a title, first-frame image, and MP4 stream URLs
- **THEN** the capture result SHALL be successful with `pageKind` set to `video`, `siteParserTag` set to `xiaohongshu`, the extracted title, the extracted lead image URL, and at least one direct downloadable video candidate

#### Scenario: H264 candidate is preferred
- **WHEN** a Xiaohongshu deep link contains both H.264 and H.265 MP4 stream candidates
- **THEN** the capture result SHALL prioritize the H.264 direct candidate ahead of H.265 candidates while preserving valid candidates for selection or download

#### Scenario: Source URL is web-openable
- **WHEN** a Xiaohongshu deep link contains `open_url` or a note id that can be converted to a web note URL
- **THEN** the capture result SHALL use an HTTP(S) Xiaohongshu source URL as `finalUrl` rather than saving the private `xhsdiscover://` URL as the primary memo link

### Requirement: Unknown-scheme browser error pages are not saved as clips
The system SHALL prevent Chromium/WebView unknown-scheme error pages from being treated as successful article content during third-party share capture.

#### Scenario: Xiaohongshu app-link navigation is intercepted
- **WHEN** a Xiaohongshu share page attempts to navigate the main frame to `xhsdiscover://...`
- **THEN** the capture flow SHALL cancel the non-HTTP(S) navigation before the browser error document replaces the share page

#### Scenario: Unsupported app-link navigation falls back safely
- **WHEN** a share page attempts to navigate the main frame to an unsupported non-HTTP(S) app scheme and no platform parser can convert it into content
- **THEN** the capture flow SHALL fail or fall back to link-only content and MUST NOT save body text containing browser error content such as `ERR_UNKNOWN_URL_SCHEME` as a successful article clip

#### Scenario: Browser error document is detected after capture
- **WHEN** DOM extraction returns a Chromium/WebView browser error document caused by an unknown URL scheme
- **THEN** the capture result SHALL be classified as failure instead of successful article content

### Requirement: Xiaohongshu parsing remains isolated from generic UI and startup flow
The system SHALL keep Xiaohongshu-specific deep link parsing inside the share parser/helper layer and MUST NOT introduce new platform-specific branches in startup coordination, note input UI, memo rendering UI, state providers, or core utilities.

#### Scenario: Parser seam owns platform details
- **WHEN** Xiaohongshu deep link support is implemented
- **THEN** Xiaohongshu field decoding SHALL live under `memos_flutter_app/lib/features/share/parsers/**` or an equivalent share parser seam, while existing video result models and UI consume generic `ShareCaptureResult` and `ShareVideoCandidate` data

#### Scenario: Dependency boundaries do not regress
- **WHEN** the implementation is complete
- **THEN** it MUST NOT add new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies beyond the pre-existing share-flow dependencies

### Requirement: Xiaohongshu note kind detection is target-scoped
The system SHALL classify Xiaohongshu share captures using evidence from the target note itself and MUST NOT classify a target image/article note as a video solely because unrelated recommendations, comments, or author sidebars contain video records.

#### Scenario: Image note page contains unrelated recommended videos
- **GIVEN** a Xiaohongshu target note has title/body text or image URLs
- **AND** unrelated page state contains records with `type` or `noteType` equal to `video`
- **WHEN** the share parser classifies the capture
- **THEN** the result SHALL use `pageKind` equal to `article`
- **AND** the result SHALL preserve the target note title and body text

#### Scenario: Target video note remains video
- **GIVEN** a Xiaohongshu target note itself exposes video type evidence or direct downloadable video candidates
- **WHEN** the share parser classifies the capture
- **THEN** the result SHALL use `pageKind` equal to `video`
- **AND** direct video candidates SHALL remain available for the quick clip media path
