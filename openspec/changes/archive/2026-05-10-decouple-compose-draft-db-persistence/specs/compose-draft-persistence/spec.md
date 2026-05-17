## ADDED Requirements

### Requirement: Compose draft persistence preserves row compatibility

The compose draft persistence layer SHALL preserve the existing `compose_drafts` row contract for create drafts and sent memo edit drafts.

#### Scenario: Create draft rows preserve existing fields
- **WHEN** a create draft row is saved and read through `ComposeDraftRepository`
- **THEN** the row SHALL preserve workspace, content, visibility, relations, attachments, location, created time, and updated time fields
- **AND** absent edit-draft fields SHALL decode as a create draft without requiring caller-side migration

#### Scenario: Edit draft rows preserve target metadata
- **WHEN** an edit draft row is saved and read through `ComposeDraftRepository`
- **THEN** the row SHALL preserve `draft_kind`, `target_memo_uid`, target memo fingerprint metadata, target memo update time, existing attachments JSON, pending attachments JSON, relations, location, and timestamps
- **AND** the row SHALL continue to identify the draft as an edit draft bound to the original memo

#### Scenario: One edit draft per target memo remains enforced
- **WHEN** multiple edit draft saves target the same `(workspace_key, target_memo_uid)`
- **THEN** compose draft persistence SHALL keep at most one visible edit draft row for that target memo in that workspace
- **AND** later saves SHALL update or replace the existing draft path used before this refactor

### Requirement: Compose draft persistence extraction preserves public behavior

The implementation SHALL extract compose draft SQLite details from the main `AppDatabase` class without changing public compose draft behavior.

#### Scenario: AppDatabase facade remains compatible
- **WHEN** existing callers use `AppDatabase` compose draft read and write methods
- **THEN** those methods SHALL remain available during this change
- **AND** they SHALL return the same row shapes and error behavior expected before extraction

#### Scenario: Desktop write proxy remains authoritative
- **WHEN** compose draft write methods execute in a desktop write-proxy configuration
- **THEN** write command dispatch SHALL continue to pass through the existing `AppDatabase` write gateway and local envelope execution path
- **AND** the extracted persistence helper SHALL NOT own remote write routing decisions

#### Scenario: Repository ownership remains stable
- **WHEN** feature or state code saves, deletes, restores, imports, or replaces compose drafts
- **THEN** it SHALL continue to go through `ComposeDraftRepository` and `ComposeDraftMutationService` ownership paths
- **AND** feature widgets SHALL NOT directly call low-level compose draft DB write methods

### Requirement: Compose draft persistence boundaries are guarded

Architecture tests SHALL protect the extracted compose draft persistence boundary from dependency and ownership regressions.

#### Scenario: Data-layer persistence does not import higher layers
- **WHEN** architecture guardrail tests inspect compose draft persistence files under `lib/data/db`
- **THEN** those files SHALL NOT import `features/`, `state/`, or `application/`
- **AND** they SHALL remain usable as data-layer SQLite helpers without presentation dependencies

#### Scenario: Direct draft write bypass is blocked
- **WHEN** architecture guardrail tests inspect feature widgets and non-owner state/application files
- **THEN** direct calls to low-level compose draft DB write methods SHALL fail the guardrail
- **AND** the allowed write path SHALL remain repository or mutation-service ownership

#### Scenario: Existing dependency allowlists do not expand
- **WHEN** this change updates architecture guardrails
- **THEN** existing reverse-dependency or direct-write allowlists SHALL shrink or remain stable
- **AND** no new `state -> features`, `application -> features`, or `core -> higher-layer` exception SHALL be introduced for compose draft persistence
