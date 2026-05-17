# local-config-manager Specification

## Purpose
TBD - created by archiving change add-local-config-manager. Update Purpose after archive.
## Requirements
### Requirement: Local manager runs through a localhost service boundary
The system SHALL provide a local-only config manager that serves a browser UI and performs all file-system writes through a localhost service boundary.

#### Scenario: Manager starts on loopback
- **WHEN** the user starts the local config manager
- **THEN** the service SHALL bind only to a loopback interface such as `127.0.0.1`
- **AND** the service SHALL serve the manager UI from `F:/Homework/memoflow_config/config/`

#### Scenario: Browser UI uses service API for writes
- **WHEN** the user saves any config change from the manager UI
- **THEN** the browser UI SHALL send the change to the localhost service API
- **AND** the browser UI SHALL NOT directly write repository files

#### Scenario: Service rejects paths outside repository root
- **WHEN** an API request references a file path
- **THEN** the service SHALL resolve the target path against the configured `memoflow_config` repository root
- **AND** the service SHALL reject path traversal or writes outside the allowed source/config paths

### Requirement: Split update source files remain the editable source of truth
The system SHALL edit split source files under `update/` and SHALL treat `dist/update/latest.json` as a generated artifact.

#### Scenario: Source files are loaded for editing
- **WHEN** the manager loads config data
- **THEN** it SHALL read `update/manifest.json`, `update/donors.json`, and announcement files referenced by `manifest.announcement_ids`
- **AND** it SHALL present a combined view without requiring edits to `dist/update/latest.json`

#### Scenario: Generated output is not directly edited
- **WHEN** the user changes update config data
- **THEN** the manager SHALL save changes to source files under `update/`
- **AND** it SHALL NOT directly mutate `dist/update/latest.json`

#### Scenario: Build script generates latest output
- **WHEN** the user requests a build from the manager
- **THEN** the service SHALL invoke the existing config build path to generate `dist/update/latest.json`
- **AND** the generated output SHALL include compatible legacy fields and authored v3 arrays

### Requirement: Update announcements are managed through announcement files and manifest indexes
The system SHALL manage version update announcements through `update/announcements/*.json` and the announcement indexes in `update/manifest.json`.

#### Scenario: Current update announcement is edited
- **WHEN** the user edits the current update announcement
- **THEN** the manager SHALL load the announcement identified by `manifest.latest_announcement_id`
- **AND** saving SHALL update the matching `update/announcements/<id>.json`

#### Scenario: New update announcement updates indexes
- **WHEN** the user creates a new update announcement
- **THEN** the manager SHALL create a numeric-string announcement file id compatible with the existing build script
- **AND** it SHALL add the id to `manifest.announcement_ids`
- **AND** it SHALL set `manifest.latest_announcement_id` to the new id
- **AND** it SHALL update `manifest.announcement_tag_index` when a release tag is provided

#### Scenario: Historical update announcements are visible
- **WHEN** the user opens the historical update announcement view
- **THEN** the manager SHALL display announcements referenced by `manifest.announcement_ids`
- **AND** it SHALL sort them consistently with the existing numeric id release-note ordering

### Requirement: V3 notices are visually managed with explicit legacy notice sync
The system SHALL provide visual management for v3 `notices[]` while preserving old-app notification compatibility through explicit opt-in legacy sync.

#### Scenario: V3 notice fields are editable
- **WHEN** the user creates or edits a notification notice
- **THEN** the manager SHALL edit a v3 notice entry in `manifest.notices[]`
- **AND** the form SHALL include id, revision, status, priority, severity, publish and expire times, audience targeting, display policy, localized title, and localized body fields

#### Scenario: One notice can sync to legacy notice
- **WHEN** the user marks a v3 notice as synced to legacy notification
- **THEN** the manager SHALL write a compatible `manifest.notice` from that notice content
- **AND** it SHALL set `manifest.notice_enabled` to true

#### Scenario: Legacy notice sync is opt-in
- **WHEN** the user edits v3 notices without selecting legacy sync
- **THEN** the manager SHALL NOT automatically mirror those notices into `manifest.notice`
- **AND** the UI SHALL make legacy notice enabled/disabled state visible

#### Scenario: Notice preview is rendered locally
- **WHEN** the user previews a notice in the manager
- **THEN** the UI SHALL render the selected localized title and body from the local JSON data
- **AND** preview SHALL NOT persist app dismissal state

### Requirement: V3 update candidates are visually managed with legacy version compatibility
The system SHALL provide visual management for v3 `updates[]` and SHALL allow explicit synchronization to legacy platform `version_info` for old app versions.

#### Scenario: V3 update candidate fields are editable
- **WHEN** the user creates or edits an update candidate
- **THEN** the manager SHALL edit a v3 update entry in `manifest.updates[]`
- **AND** the form SHALL include id, status, priority, platform, channel, version, force flag, download URL, release note id, publish and expire times, and audience targeting

#### Scenario: Primary update can sync to legacy version info
- **WHEN** the user marks an update candidate as the legacy primary update for a platform
- **THEN** the manager SHALL update the corresponding `manifest.version_info.<platform>` block
- **AND** old app versions SHALL continue to receive compatible latest-version and download URL fields after build

#### Scenario: Update preview summarizes eligibility fields
- **WHEN** the user previews an update candidate
- **THEN** the UI SHALL show the target platform, channel, version, force status, schedule, download URL, and linked release note state from local JSON data

### Requirement: Donors are managed through donors source and asset references
The system SHALL manage donor records through `update/donors.json` and SHALL preserve references used by update announcements.

#### Scenario: Donor list is edited
- **WHEN** the user adds, edits, or deletes a donor
- **THEN** the manager SHALL save the donor list to `update/donors.json`
- **AND** each donor SHALL preserve id, display name, and avatar URL fields

#### Scenario: Deleting referenced donor is guarded
- **WHEN** the user attempts to delete a donor referenced by any `new_donor_ids` entry in announcement files
- **THEN** the manager SHALL warn before saving the deletion
- **AND** it SHALL identify at least one referencing announcement

#### Scenario: Donor preview displays local data
- **WHEN** the user opens the donor view
- **THEN** the manager SHALL display donor names and avatar references from `update/donors.json`

### Requirement: Manager validates and builds config locally
The system SHALL expose fixed local validation and build actions and SHALL surface their diagnostics in the UI.

#### Scenario: Validate source config
- **WHEN** the user runs validation from the manager
- **THEN** the service SHALL run the existing split-config validation command
- **AND** the UI SHALL show success, warnings, or errors from the validation result

#### Scenario: Validate v3 production safety
- **WHEN** the manager validates v3 notices or updates
- **THEN** it SHALL report blocker diagnostics for invalid JSON shape, duplicate ids, draft production items, invalid schedule bounds, missing public notice content, and invalid forced update URLs
- **AND** it SHALL report warning diagnostics for long expiry windows, missing English body content, unresolved release note links, Play-channel APK links, and suspicious test/debug wording

#### Scenario: Build generated latest config
- **WHEN** the user runs build from the manager
- **THEN** the service SHALL generate `dist/update/latest.json` through the existing build script
- **AND** the UI SHALL show the generated output path and command result

### Requirement: Local manager preserves app architecture boundaries
The system SHALL keep the local config manager outside Flutter runtime layers and SHALL NOT introduce new app-layer reverse dependencies.

#### Scenario: Tool files stay outside app runtime
- **WHEN** the local config manager is implemented
- **THEN** new manager runtime files SHALL be placed in `F:/Homework/memoflow_config/config/`
- **AND** they SHALL NOT be added under `memos_flutter_app/lib`

#### Scenario: No Flutter runtime coupling is introduced
- **WHEN** the change is complete
- **THEN** it SHALL NOT introduce new `state -> features`, `application -> features`, or `core -> state|application|features` imports in `memos_flutter_app`
- **AND** config-file mutation logic SHALL remain owned by the local service boundary

