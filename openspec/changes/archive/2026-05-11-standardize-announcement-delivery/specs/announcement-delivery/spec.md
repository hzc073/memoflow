## ADDED Requirements

### Requirement: Announcement remediation phases are enforced
The system SHALL implement announcement delivery standardization through the ordered Phase A-E rule so preview safety, contract normalization, delivery scheduling, architecture cleanup, and release governance are all covered before the change is considered complete.

#### Scenario: Phase A establishes safe preview workflow
- **WHEN** the change implements Phase A
- **THEN** Debug tools SHALL be able to preview announcement config from a non-production preview source without changing formal startup production behavior
- **AND** formal startup SHALL continue to use the production config source only

#### Scenario: Phase B establishes the v3 delivery contract
- **WHEN** the change implements Phase B
- **THEN** the system SHALL parse a schema v3 announcement contract with item `status`, `publish_at`, `expire_at`, audience targeting, and id/revision dismissal
- **AND** legacy config parsing SHALL remain compatible for existing remote JSON fields

#### Scenario: Phase C establishes startup queue policy
- **WHEN** the change implements Phase C
- **THEN** startup announcement delivery SHALL evaluate eligible candidates through a priority queue
- **AND** startup SHALL show at most one non-forced announcement item per launch

#### Scenario: Phase D establishes presentation boundary cleanup
- **WHEN** the change implements Phase D
- **THEN** application-layer announcement policy SHALL produce presentation requests without importing `features/updates` dialogs
- **AND** architecture guardrails SHALL prevent reintroducing the removed `application/updates -> features/updates` dialog dependencies

#### Scenario: Phase E establishes release governance
- **WHEN** the change implements Phase E
- **THEN** production announcement config SHALL have validation, example config, release checklist, and rollback documentation

### Requirement: Config sources are environment aware
The system SHALL distinguish formal production startup config from Debug preview config sources.

#### Scenario: Formal startup uses production config
- **WHEN** formal startup schedules announcement delivery
- **THEN** the fetch path SHALL use production config sources
- **AND** Debug-only preview sources SHALL NOT affect formal startup behavior

#### Scenario: Debug tools can preview non-production config
- **WHEN** a developer opens announcement preview tools in a Debug build
- **THEN** the tools SHALL allow previewing announcement content from a preview source
- **AND** the preview path SHALL NOT persist user-facing dismissal state as if the announcement had been formally shown

#### Scenario: Custom preview failures are isolated
- **WHEN** a selected preview config source fails to load or parse
- **THEN** the Debug preview surface SHALL report the failure
- **AND** production startup config source selection SHALL remain unchanged

### Requirement: Schema v3 announcement config is parsed with legacy compatibility
The system SHALL parse schema v3 `notices`, `updates`, and `release_notes` while preserving compatibility with legacy `version_info`, `announcement`, `notice_enabled`, `notice`, and `release_notes` fields.

#### Scenario: V3 notices become delivery candidates
- **WHEN** schema v3 config includes `notices`
- **THEN** each valid notice item SHALL be normalized into a notice delivery candidate with id, revision, status, schedule, audience, display policy, priority, and localized content

#### Scenario: V3 updates become delivery candidates
- **WHEN** schema v3 config includes `updates`
- **THEN** each valid update item SHALL be normalized into an update delivery candidate with id, platform, channel, version, force flag, publish schedule, download URL, and release note link

#### Scenario: Legacy config remains compatible
- **WHEN** a remote config omits schema v3 `notices` and `updates`
- **THEN** the system SHALL preserve existing legacy update announcement and notice behavior

#### Scenario: V3 prefers explicit fields over legacy fallback
- **WHEN** both schema v3 delivery candidates and legacy announcement fields are present
- **THEN** the new delivery evaluator SHALL prefer schema v3 candidates for startup delivery
- **AND** legacy fields SHALL remain available for older clients and manual compatibility surfaces

### Requirement: Announcement eligibility respects status schedule audience and dismissal
The system SHALL only deliver announcement candidates that satisfy status, schedule, audience, and dismissal rules.

#### Scenario: Public status is required for formal delivery
- **WHEN** formal startup evaluates announcement candidates
- **THEN** only candidates with `status` equal to `public` SHALL be eligible
- **AND** candidates with `draft`, `preview`, or `archived` status SHALL NOT be formally delivered

#### Scenario: Schedule bounds gate delivery
- **WHEN** a candidate has `publish_at` in the future or `expire_at` in the past
- **THEN** the candidate SHALL be ineligible for formal startup delivery

#### Scenario: Audience gates delivery
- **WHEN** a candidate declares platform, channel, minimum app version, or maximum app version targeting
- **THEN** the candidate SHALL be eligible only when the current app context satisfies every declared targeting condition

#### Scenario: Dismissal policy gates repeated delivery
- **WHEN** a candidate was already acknowledged according to its `dismiss_policy`
- **THEN** the candidate SHALL be ineligible until its policy permits delivery again

### Requirement: Startup delivery queue prioritizes announcement candidates
The system SHALL rank eligible startup announcement candidates and prevent non-forced dialog stacking.

#### Scenario: Forced update has highest priority
- **WHEN** an eligible forced update candidate exists
- **THEN** the startup delivery queue SHALL select the forced update before every non-forced candidate

#### Scenario: Candidate priority resolves ordinary delivery order
- **WHEN** multiple non-forced candidates are eligible during the same startup
- **THEN** the delivery queue SHALL rank critical blocking notices before optional update prompts, release highlights, and ordinary notices

#### Scenario: Startup shows at most one non-forced candidate
- **WHEN** the startup queue selects a non-forced candidate
- **THEN** the system SHALL NOT immediately cascade another non-forced announcement dialog in the same startup pass

### Requirement: Announcement presentation is isolated from application policy
The system SHALL separate application-layer announcement policy from feature-layer dialog rendering.

#### Scenario: Application produces presentation request
- **WHEN** application-layer announcement delivery selects a candidate
- **THEN** it SHALL produce an application-level presentation request and await an application-level presentation result
- **AND** it SHALL NOT import `features/updates` dialog widgets

#### Scenario: Feature layer renders dialogs
- **WHEN** a presentation request reaches the feature-layer presenter
- **THEN** the feature layer SHALL render the appropriate update or notice dialog
- **AND** it SHALL translate user actions into the application-level presentation result

#### Scenario: Guardrail protects the boundary
- **WHEN** architecture guardrail tests inspect `application/updates`
- **THEN** they SHALL fail if direct imports of `features/updates` dialogs are reintroduced

### Requirement: Production announcement config is validated before release
The system SHALL provide local validation rules for production announcement config.

#### Scenario: Validation blocks unsafe production config
- **WHEN** production config contains malformed JSON, duplicate ids, invalid schedule bounds, missing public content, invalid forced update URLs, or `draft` items
- **THEN** validation SHALL fail with actionable diagnostics

#### Scenario: Validation warns on ambiguous config
- **WHEN** production config contains suspicious but not always invalid content such as very long expiry windows, missing English content, unresolved release note links, or ambiguous testing wording
- **THEN** validation SHALL report warnings for human review

#### Scenario: Release documentation defines rollback
- **WHEN** an announcement release is prepared
- **THEN** documentation SHALL describe how to preview, validate, publish, and roll back production announcement config
