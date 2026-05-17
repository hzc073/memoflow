## ADDED Requirements

### Requirement: AI-assisted memo search UI is localized
The system SHALL render all user-visible AI-assisted memo search copy through the existing localization system for every supported app locale.

#### Scenario: AI search entry points use localized copy
- **WHEN** keyword search results are empty or the user is viewing keyword results for a non-empty query
- **THEN** the AI-assisted search affordance SHALL render localized action text instead of hard-coded English copy.

#### Scenario: AI search result labels use localized copy
- **WHEN** AI-assisted semantic results are displayed
- **THEN** AI result labels, keyword recovery actions, and search source labels SHALL render localized copy for the active locale.

#### Scenario: AI search failure states use localized copy
- **WHEN** AI-assisted search cannot run because embedding configuration is missing or the provider returns an error
- **THEN** the configuration-required title, configuration guidance, error title, and recovery action SHALL render localized copy for the active locale.

#### Scenario: AI search empty states use localized copy
- **WHEN** AI-assisted search completes successfully without eligible semantic matches
- **THEN** the AI-specific empty-state title and guidance SHALL render localized copy distinct from the default keyword no-results state.

#### Scenario: Hard-coded AI search UI copy is guarded
- **WHEN** memo list widget code is changed
- **THEN** automated tests or guardrails SHALL fail if known AI-assisted search user-visible English phrases are reintroduced directly in memo list widgets.
