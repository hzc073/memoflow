# memo-thumbnail-rendering Specification

## Purpose
TBD - created by archiving change fix-memo-thumbnail-aspect-crop. Update Purpose after archive.
## Requirements
### Requirement: Memo card thumbnails preserve visual aspect ratio
The system SHALL render memo card image thumbnails without stretching image pixels. Thumbnail tiles SHALL 在保持 source image aspect ratio 的前提下填满分配到的 grid cell，并通过 center-cropping 裁掉无法显示的溢出区域。

#### Scenario: Wide image rendered in square home tile
- **WHEN** a home memo card renders a wide image attachment in a square thumbnail tile
- **THEN** the thumbnail SHALL 填满 tile，且不发生 horizontal 或 vertical pixel stretching
- **AND** excess source width SHALL 被裁切，而不是被挤压进 tile

#### Scenario: Tall image rendered in square home tile
- **WHEN** a home memo card renders a tall image attachment in a square thumbnail tile
- **THEN** the thumbnail SHALL 填满 tile，且不发生 horizontal 或 vertical pixel stretching
- **AND** excess source height SHALL 被裁切，而不是被挤压进 tile

#### Scenario: Height-limited media grid
- **WHEN** home memo card media grid 因 card `maxHeight` 限制而降低 tile height
- **THEN** visible image thumbnails SHALL 仍然保持 source aspect ratio
- **AND** height-limited tile shape SHALL NOT 把 decoded image 强制变成相同 exact aspect ratio

### Requirement: Thumbnail cache sizing is aspect-safe
The system SHALL 仅将 thumbnail cache/decode dimensions 视为内存和性能优化。Cache sizing MUST NOT 要求把图片 decode 成与 source image aspect ratio 不同的 bitmap aspect ratio。

#### Scenario: Source dimensions are available
- **WHEN** memo thumbnail caller 同时知道 tile dimensions 和 source image dimensions
- **THEN** cache target SHALL 在满足 tile cover 需求的同时，让 decoded bitmap 保持 source aspect ratio
- **AND** cache target SHALL 受 configured maximum decode size 约束

#### Scenario: Source dimensions are unavailable
- **WHEN** memo thumbnail caller 不知道 source image dimensions
- **THEN** cache target SHALL 避免可能让 unknown-ratio images 变形的 exact two-axis sizing
- **AND** rendered thumbnail SHALL 仍使用 aspect-preserving cover behavior

### Requirement: Composer pending thumbnails preserve visual aspect ratio
The system SHALL render pending image attachment thumbnails in composer surfaces without stretching image pixels. Pending thumbnails SHALL 填满 composer attachment tile，并在不知道 source dimensions 时仍避免 exact two-axis decode/cache sizing。

#### Scenario: Pending image rendered in note input sheet
- **WHEN** user adds an image attachment before publishing a memo and the note input sheet renders the pending image tile
- **THEN** the pending thumbnail SHALL 填满 square attachment tile，且不发生 horizontal 或 vertical pixel stretching
- **AND** excess source area SHALL 被 center-cropped，而不是被挤压进 tile

#### Scenario: Pending image rendered in inline compose card
- **WHEN** inline compose card renders a pending image attachment tile
- **THEN** the pending thumbnail SHALL 使用 aspect-preserving cover behavior
- **AND** cache sizing SHALL NOT 把 unknown-dimension local image 强制 decode 成 tile 的 exact square dimensions

### Requirement: Thumbnail rendering remains localized to memo presentation
The system SHALL 在不改变 full-screen image preview behavior、Memos server file routes 或 attachment API compatibility 的前提下修复 memo card thumbnail distortion。

#### Scenario: Opening a thumbnail preview
- **WHEN** user 从 memo card thumbnail 打开图片
- **THEN** full-screen preview/gallery SHALL 继续使用现有 non-cropping preview behavior 渲染图片

#### Scenario: Remote Memos attachment URL
- **WHEN** memo thumbnail source 是 remote Memos attachment URL
- **THEN** app SHALL 继续使用现有 resolved URL 和 authorization context
- **AND** fix SHALL NOT 要求修改 server endpoint 或 request/response model

