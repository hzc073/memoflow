# xiaohongshu-share-media-attachments Specification

## Purpose
TBD - created by archiving change auto-save-xiaohongshu-share-media-attachments. Update Purpose after archive.
## Requirements
### Requirement: Quick clip classifies Xiaohongshu media type
The system SHALL classify successful Xiaohongshu share capture results into video notes or image/article notes before deciding which media attachment path to run.

#### Scenario: Xiaohongshu video result is classified for video attachment
- **WHEN** quick clip receives a successful `ShareCaptureResult` with `siteParserTag` equal to `xiaohongshu`, `pageKind` equal to `video`, and at least one direct `ShareVideoCandidate`
- **THEN** the system SHALL select the video attachment path
- **AND** the selected candidate SHALL prefer broadly compatible direct video candidates when multiple candidates are available

#### Scenario: Xiaohongshu image or article result is classified for image attachment
- **WHEN** quick clip receives a successful Xiaohongshu capture result that is not a direct video result
- **THEN** the system SHALL select the image/article attachment path
- **AND** the system SHALL use prepared inline image seeds or deferred inline image discovery as the media source

### Requirement: Full quick clip saves Xiaohongshu media as attachments
The system SHALL save Xiaohongshu media attachments automatically when quick clip is running in full media mode.

#### Scenario: Xiaohongshu image CDN URLs are normalized before discovery
- **WHEN** a Xiaohongshu image/article capture exposes target-note image URLs using `http` on a known Xiaohongshu image CDN host
- **THEN** the parser or cleanup layer SHALL normalize those URLs to `https`
- **AND** parser-level image attachment discovery SHALL use the normalized URLs

### Requirement: Lightweight quick clip modes do not download media
The system SHALL respect explicit quick clip submission modes that intentionally avoid media downloads.

#### Scenario: Title and link only skips all media
- **WHEN** `ShareQuickClipSubmission.titleAndLinkOnly` is true
- **THEN** the system SHALL save only the title/link memo content
- **AND** the system SHALL NOT run Xiaohongshu image or video download paths

#### Scenario: Text only skips all media
- **WHEN** `ShareQuickClipSubmission.textOnly` is true
- **THEN** the system SHALL save captured text content without media attachments
- **AND** the system SHALL NOT run Xiaohongshu image or video download paths

### Requirement: Media attachment failures preserve captured memo content
The system SHALL preserve the captured memo content and clip metadata when Xiaohongshu media attachment preparation fails after text capture succeeds.

#### Scenario: Video download fails after memo update
- **WHEN** a Xiaohongshu video note capture succeeds but the selected video candidate cannot be downloaded or staged
- **THEN** the system SHALL keep the memo content and clip metadata saved
- **AND** the system SHALL record diagnostic information about the media attachment failure
- **AND** the system SHALL NOT delete the memo solely because media attachment saving failed

#### Scenario: Image attachment preparation fails after memo update
- **WHEN** a Xiaohongshu image/article capture succeeds but one or more image attachments cannot be prepared or staged
- **THEN** the system SHALL keep the memo content and any successfully attached images
- **AND** the system SHALL record diagnostic information for failed image attachments

### Requirement: Shared attachment append behavior is owned by a stable seam
The system SHALL append third-party share media attachments through a reusable mutation or attachment appender seam rather than duplicating UI-specific logic in quick clip.

#### Scenario: Quick clip appends media through plain request data
- **WHEN** quick clip has downloaded a Xiaohongshu image or video file for a memo
- **THEN** it SHALL pass plain attachment request data to the shared appender seam
- **AND** the appender seam SHALL own memo attachment updates and outbox enqueueing
- **AND** lower-level state or data layers SHALL NOT depend on Xiaohongshu parser classes or share UI widgets

#### Scenario: Existing dependency hotspots do not get worse
- **WHEN** Xiaohongshu media auto-save is implemented during `evolve_modularity`
- **THEN** the implementation SHALL NOT introduce new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies
- **AND** shared deferred video attachment logic SHALL NOT remain available only inside `NoteInputSheet`

