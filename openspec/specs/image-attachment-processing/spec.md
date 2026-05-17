## Purpose

Define attachment processing behavior so selected local attachments become visible immediately, expensive image preparation stays off the user-visible path, safe resize preserves display aspect ratio, and upload consumes ready processed metadata without changing server API compatibility.

## Requirements

### Requirement: Selected attachments become visible before processing completes
The system SHALL admit selected local attachments into composer state once picker or file metadata is available, without waiting for staging, compression, upload preprocessing, or sync completion.

#### Scenario: Multiple selected images are shown immediately
- **WHEN** the user selects multiple local image attachments and image compression is enabled
- **THEN** the composer SHALL show those selected attachments using their local preview data before staging or compression finishes
- **AND** each attachment SHALL expose a processing status until it is ready or failed

#### Scenario: Processing failure remains visible
- **WHEN** a selected attachment cannot be staged or processed after it has been admitted
- **THEN** the composer SHALL keep a visible failed attachment state instead of silently removing the user's selection
- **AND** the user SHALL be able to remove or retry the failed attachment before submitting

### Requirement: Memo submit waits for attachment readiness
The system SHALL prevent memo creation or update from omitting selected attachments that are still being prepared.

#### Scenario: Submit while attachments are still staging
- **WHEN** the user attempts to submit a memo while one or more selected attachments are not ready
- **THEN** the system SHALL either block the submit action with visible processing feedback or wait until those attachments become ready
- **AND** the memo SHALL NOT be created successfully with those selected attachments missing

#### Scenario: Submit with failed attachments
- **WHEN** one or more selected attachments are in a failed processing state
- **THEN** the system SHALL require the user to remove, retry, or resolve those failed attachments before creating or updating the memo

### Requirement: Staging is lightweight and idempotent
The system SHALL keep attachment staging focused on stable local file management and SHALL avoid expensive image decoding on the required staging path.

#### Scenario: Managed attachments are staged once
- **WHEN** an attachment path already belongs to the managed queued-attachment directory and the file exists
- **THEN** staging SHALL return that managed file without copying it again
- **AND** staging SHALL NOT run synchronous image dimension probing only for diagnostic logging

#### Scenario: Multi-attachment staging avoids serial diagnostic probes
- **WHEN** multiple image attachments are staged in one user action
- **THEN** required staging work SHALL NOT synchronously decode every image before the attachments can appear in the composer

### Requirement: Compression runs through a bounded background executor
The system SHALL run expensive image compression work behind an application-layer executor that does not block the UI isolate and limits concurrent compression jobs.

#### Scenario: Native compression does not block composer interaction
- **WHEN** compression uses a synchronous native engine such as Caesium FFI
- **THEN** the compression call SHALL run through a background execution seam rather than directly blocking the UI isolate
- **AND** the composer SHALL remain responsive while compression is in progress

#### Scenario: Duplicate compression work is coalesced
- **WHEN** the same source image and compression settings are requested while an equivalent compression job is already running
- **THEN** the system SHALL share the in-flight result instead of starting duplicate compression work

### Requirement: Source image metadata is probed once per processing pass
The system SHALL reuse source image probe metadata across preprocessing, compression planning, compression logging, and upload metadata generation during a single attachment processing pass.

#### Scenario: Preprocessor passes probe metadata into the pipeline
- **WHEN** an image attachment is preprocessed for upload
- **THEN** the compression pipeline SHALL receive the existing source probe metadata or an equivalent immutable metadata object
- **AND** the pipeline SHALL NOT re-decode the same source image solely to rediscover dimensions, format, animation state, or EXIF orientation

### Requirement: Safe resize preserves long image and EXIF aspect ratio
The system SHALL preserve intended display aspect ratio when compressing photos, screenshots, long images, and EXIF-rotated images.

#### Scenario: Long screenshot is not unreadably narrowed by default resize
- **WHEN** a selected image is classified as a long image or long screenshot by aspect ratio or pixel-height policy
- **THEN** default compression SHALL avoid resize behavior that would substantially narrow the readable edge
- **AND** the output SHALL preserve the source display aspect ratio within the configured tolerance

#### Scenario: EXIF-rotated image uses the correct resize axes
- **WHEN** a source image has EXIF orientation that swaps display width and height
- **THEN** resize planning SHALL preserve display-space aspect ratio
- **AND** engine parameters SHALL be mapped to the encoded pixel axes without stretching the output

#### Scenario: Aspect-ratio validation falls back safely
- **WHEN** compressed output dimensions deviate from the expected display aspect ratio beyond tolerance
- **THEN** the system SHALL discard that unsafe output and use the original file or another known-safe fallback
- **AND** the fallback reason SHALL be recorded for diagnostics

### Requirement: Upload uses processed attachment metadata without API changes
The system SHALL upload the ready processed attachment artifact and update local attachment metadata without changing existing server API compatibility behavior.

#### Scenario: Upload consumes ready processed file
- **WHEN** a ready attachment is synchronized
- **THEN** upload SHALL read the processed file path, filename, mime type, size, dimensions, and hash from the attachment processing result
- **AND** the server-facing attachment payload format SHALL remain compatible with the existing memo/resource routes

#### Scenario: Compression disabled still preserves readiness contract
- **WHEN** image compression is disabled or a user selects original image upload
- **THEN** attachment processing SHALL still produce a ready attachment result
- **AND** the submit readiness gate SHALL behave the same as compressed attachments
