## MODIFIED Requirements

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
