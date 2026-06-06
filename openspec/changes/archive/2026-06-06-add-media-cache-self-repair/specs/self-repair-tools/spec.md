## ADDED Requirements

### Requirement: Help and diagnostics exposes storage space as a dedicated page
The system SHALL expose MemoFlow storage diagnostics from `Settings -> Help & Diagnostics -> Storage Space` rather than from the self-repair action list.

#### Scenario: User sees help and diagnostics from settings
- **WHEN** the user opens `Settings`
- **THEN** the settings home SHALL show a `Help & Diagnostics` entry
- **AND** the entry SHALL replace the previous user-facing `Feedback` settings-home label for this diagnostic group
- **AND** existing feedback, log export, and self-repair capabilities SHALL remain reachable from the diagnostic group

#### Scenario: User opens storage space from help and diagnostics
- **WHEN** the user opens `Settings -> Help & Diagnostics`
- **THEN** the page SHALL provide a `Storage Space` navigation entry
- **AND** activating the entry SHALL push a dedicated storage-space page
- **AND** the storage-space page SHALL NOT be embedded inside `Self Repair`

#### Scenario: Self repair no longer owns media cache cleanup UI
- **WHEN** the user opens `Settings -> Help & Diagnostics -> Self Repair`
- **THEN** the self-repair page SHALL provide local repair actions for abnormal tags, search index, and statistics cache
- **AND** the self-repair page SHALL NOT show a media-cache cleanup button
- **AND** the self-repair page SHALL NOT show media-cache aggregate/category rows

### Requirement: Storage space summarizes MemoFlow known usage
The system SHALL summarize MemoFlow known local usage on the dedicated storage-space page without reporting other apps' usage.

#### Scenario: User sees MemoFlow known usage total
- **WHEN** the storage-space summary is available
- **THEN** the storage-space page SHALL show MemoFlow known usage total
- **AND** the page SHALL describe the value as MemoFlow known usage rather than total system app storage
- **AND** the page SHALL NOT show other apps' used space as a category, segment, or amount

#### Scenario: Device capacity is available
- **WHEN** device total capacity is available from the platform adapter
- **THEN** the storage-space page MAY show MemoFlow known usage as a percentage of device capacity
- **AND** the percentage SHALL use MemoFlow known usage as the numerator
- **AND** the page SHALL NOT derive or display other apps' usage from the remaining capacity

#### Scenario: Device capacity is unavailable
- **WHEN** device total capacity is unavailable, unsupported, or fails to load
- **THEN** the storage-space page SHALL still show MemoFlow known usage total and category rows
- **AND** the page SHALL gracefully omit or downgrade the device-capacity percentage
- **AND** cache cleanup SHALL remain available when the cache maintenance seam is available

#### Scenario: User sees storage categories
- **WHEN** the storage-space summary is available
- **THEN** the page SHALL show category-level sizes for cache, note content, note images, note videos, note audio, and note files
- **AND** note content SHALL be estimated from local memo content bytes
- **AND** note image/video/audio/file categories SHALL be estimated from attachment metadata rather than filesystem-wide scans
- **AND** the page SHALL NOT show a browsable cache gallery
- **AND** the page SHALL NOT expose individual cached image selection, URL selection, per-image deletion controls, or per-attachment cleanup controls

### Requirement: Storage space clears only safe cache data
The system SHALL allow active cleanup only for safe MemoFlow cache data from the storage-space page.

#### Scenario: User sees cache cleanup action
- **WHEN** the user opens the storage-space page
- **THEN** the cache category SHALL provide an active cleanup control
- **AND** note content, note images, note videos, note audio, and note files SHALL NOT provide active cleanup controls

#### Scenario: User confirms cache cleanup
- **WHEN** the user confirms cache cleanup from the storage-space page
- **THEN** the system SHALL clear safe media-derived caches including network image cache, Flutter image memory cache, video thumbnail cache, and explicitly allowlisted media temporary caches
- **AND** memo content, accounts, preferences, local library source files, attachment source files, WebDAV backups, pending sync queues, and remote server data SHALL NOT be deleted by this action
- **AND** cached media MAY be downloaded or regenerated again when the user views related content later
- **AND** the storage-space summary SHALL refresh after cleanup completes

#### Scenario: User cancels cache cleanup
- **WHEN** the cache cleanup confirmation is shown
- **AND** the user cancels the confirmation
- **THEN** no cache cleanup SHALL run
- **AND** cached media files SHALL remain unchanged by this action

#### Scenario: Cache cleanup reports partial failures
- **WHEN** one allowlisted cache category fails to clear but another category completes
- **THEN** the page SHALL show a recoverable localized failure or partial-failure result
- **AND** the user SHALL remain able to export logs or use the existing feedback/reporting path
- **AND** successful category cleanup SHALL NOT be rolled back

### Requirement: Storage-space maintenance preserves modular boundaries
The system MUST implement storage statistics and cache cleanup through reusable maintenance seams rather than embedding cache-manager, database-summary, platform-capacity, or filesystem logic in settings widgets.

#### Scenario: Settings UI routes storage-space intent only
- **WHEN** the storage-space UI is added
- **THEN** settings widgets MUST only render localized copy, summary state, confirmations, operation state, and user actions
- **AND** settings widgets MUST NOT directly import `DefaultCacheManager`, `PaintingBinding`, `path_provider`, media cache helper internals, platform capacity internals, DB persistence helpers, or filesystem directory traversal utilities for cleanup/statistics

#### Scenario: Maintenance seam owns allowlisted cache categories
- **WHEN** cache size is calculated or cache cleanup runs
- **THEN** a state/application maintenance seam MUST own the allowlist of cache categories
- **AND** the implementation MUST NOT recursively clear broad temporary, support, documents, account, database, local library, or sync directories

#### Scenario: Storage summary seam owns MemoFlow usage categories
- **WHEN** MemoFlow known usage is calculated
- **THEN** a state/application/data seam MUST own memo-content and attachment-size aggregation
- **AND** the settings UI MUST NOT parse memo rows, attachment JSON, raw SQLite rows, or attachment metadata directly
- **AND** the implementation SHOULD define deterministic handling for missing attachment sizes and duplicate attachment identities

#### Scenario: No storage-space reverse dependency is introduced
- **WHEN** storage-space diagnostics are implemented during `evolve_modularity`
- **THEN** the implementation MUST NOT introduce new `state -> features`, `application -> features`, or `core -> state|application|features` imports
- **AND** reusable storage summary or cache cleanup logic SHALL NOT be hidden inside screen or widget files
