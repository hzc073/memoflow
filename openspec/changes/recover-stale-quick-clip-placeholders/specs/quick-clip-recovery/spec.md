# quick-clip-recovery Specification

## Purpose

Define how full quick clip placeholders recover after app backgrounding, process death, restart, or capture failure.

## ADDED Requirements

### Requirement: Full quick clip placeholders have durable recovery jobs
The system SHALL persist a recovery job whenever a full quick clip creates a placeholder memo before content extraction completes.

#### Scenario: Full quick clip creates placeholder and job atomically enough for recovery
- **WHEN** a user starts a full quick clip for a supported URL
- **THEN** the system SHALL create a placeholder memo
- **AND** the system SHALL persist a pending recovery job with enough data to retry extraction or write fallback link content
- **AND** the job SHALL identify the placeholder memo by `memoUid` and recovery-safe placeholder matching data

#### Scenario: Title-and-link-only quick clip does not create recovery job
- **WHEN** a user starts quick clip with `ShareQuickClipSubmission.titleAndLinkOnly` enabled
- **THEN** the system SHALL save the title/link memo directly
- **AND** the system SHALL NOT create a quick clip recovery job

### Requirement: Stale quick clip placeholders reach a terminal user-visible state
The system SHALL ensure a full quick clip placeholder does not remain in a processing state forever.

#### Scenario: Recovery retry succeeds after app restart
- **GIVEN** a full quick clip placeholder memo and pending recovery job exist
- **AND** the original in-memory capture task is no longer running
- **WHEN** the app starts or resumes with a workspace/database available
- **AND** recovery retries extraction successfully
- **THEN** the system SHALL update the existing placeholder memo with captured content
- **AND** the system SHALL mark the recovery job completed

#### Scenario: Recovery retry fails and saves fallback link content
- **GIVEN** a full quick clip placeholder memo and pending recovery job exist
- **WHEN** recovery retries extraction and the retry fails or times out
- **THEN** the system SHALL replace the placeholder with saved-link fallback content
- **AND** the fallback content SHALL include the source link
- **AND** the fallback content SHALL preserve user-selected quick clip tags
- **AND** the system SHALL mark the recovery job completed or terminal

#### Scenario: Expired stale job saves fallback link content
- **GIVEN** a full quick clip recovery job remains pending beyond the configured stale threshold
- **WHEN** recovery scans pending jobs
- **THEN** the system SHALL write saved-link fallback content when the placeholder is still safe to update
- **AND** the memo SHALL no longer display `剪藏中...` or `Clipping...` as an indefinite processing state

### Requirement: Recovery does not overwrite user-edited placeholders
The system SHALL NOT overwrite a quick clip placeholder memo unless it can verify that the memo still matches the original placeholder for the recovery job.

#### Scenario: User edited placeholder is skipped
- **GIVEN** a pending quick clip recovery job exists
- **AND** the corresponding memo content no longer matches the hidden marker or original placeholder lookup content
- **WHEN** recovery scans the job
- **THEN** the system SHALL NOT replace the memo content with captured or fallback content
- **AND** the system SHALL mark or log the job as abandoned, skipped, or failed for diagnostics

#### Scenario: Missing placeholder is terminal
- **GIVEN** a pending quick clip recovery job exists
- **AND** the corresponding memo no longer exists
- **WHEN** recovery scans the job
- **THEN** the system SHALL mark the job terminal
- **AND** the system SHALL NOT create a duplicate memo

### Requirement: Quick clip recovery is idempotent and lifecycle-safe
The system SHALL process quick clip recovery jobs idempotently across startup, resume, and share-flow completion triggers.

#### Scenario: Multiple lifecycle triggers do not duplicate work
- **GIVEN** a pending quick clip recovery job exists
- **WHEN** startup and resume recovery triggers run close together
- **THEN** the system SHALL process the job at most once at a time
- **AND** the system SHALL NOT duplicate memo updates, attachments, clip metadata, or outbox entries

#### Scenario: Completed job is ignored by future scans
- **GIVEN** a quick clip recovery job has already completed successfully or terminally
- **WHEN** recovery scans jobs again
- **THEN** the system SHALL NOT retry or fallback that job again

### Requirement: Recovery preserves architecture boundaries
The system SHALL keep durable quick clip recovery policy in a focused service or persistence seam and MUST NOT hide reusable recovery logic inside UI widgets.

#### Scenario: Recovery policy is not owned by share UI widgets
- **WHEN** full quick clip recovery is implemented
- **THEN** retry/fallback/job-state policy SHALL be owned by a reusable service, coordinator, or state/data seam
- **AND** share UI widgets SHALL NOT become the owner of durable recovery orchestration

#### Scenario: API compatibility is unchanged
- **WHEN** quick clip recovery is implemented
- **THEN** Memos server API request/response models, route adapters, and version compatibility behavior SHALL remain unchanged
