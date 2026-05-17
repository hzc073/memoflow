## ADDED Requirements

### Requirement: Startup notice delivery respects display surface
The system SHALL only select schema v3 notice candidates for formal startup delivery when their `display.surface` is `startup_dialog`.

#### Scenario: Startup dialog notice remains eligible
- **WHEN** formal startup evaluates a public schema v3 notice candidate with `display.surface` equal to `startup_dialog`
- **THEN** the candidate remains eligible if its status, schedule, audience, content, and dismissal rules also pass

#### Scenario: Release highlight notice is excluded from startup
- **WHEN** formal startup evaluates a public schema v3 notice candidate with `display.surface` equal to `release_highlight`
- **THEN** the candidate is not selected for the startup notice dialog

#### Scenario: Release highlight is the only notice candidate
- **WHEN** formal startup evaluates config where every otherwise eligible notice candidate uses a non-startup surface
- **THEN** startup delivery does not show a notice dialog for those candidates

### Requirement: Debug preview renders schema v3 notice candidates
The system SHALL allow Debug announcement preview to render schema v3 `notices[]` candidates from preview, custom URL, and local JSON config sources even when legacy `notice` is absent.

#### Scenario: Preview config contains only v3 notices
- **WHEN** a developer previews a loaded schema v3 config that has no legacy `notice` but has at least one previewable notice candidate in `notices[]`
- **THEN** Debug preview renders a notice dialog using that candidate's localized title and body content

#### Scenario: Local JSON preview contains only v3 notices
- **WHEN** a developer selects the local JSON preview source and pastes schema v3 config with only `notices[]`
- **THEN** Debug preview can render one previewable v3 notice candidate without requiring legacy fallback fields

#### Scenario: Debug preview does not persist formal dismissal state
- **WHEN** Debug preview renders a schema v3 notice candidate
- **THEN** the app does not write `seenNoticeRevisions`, `lastSeenNoticeHash`, or other formal startup dismissal state for that preview action

### Requirement: V3 notice dialog content is resolved consistently
The system SHALL resolve schema v3 notice candidate title and body fallback behavior consistently between startup presentation and Debug preview.

#### Scenario: Candidate has matching locale content
- **WHEN** startup presentation or Debug preview renders a schema v3 notice candidate with content matching the active locale
- **THEN** the dialog uses the matching localized title and body content

#### Scenario: Candidate relies on fallback content
- **WHEN** startup presentation or Debug preview renders a schema v3 notice candidate without content matching the active locale
- **THEN** the dialog uses the same English, Chinese, first-available, or fallback content order in both paths
