## ADDED Requirements

### Requirement: AI-assisted memo search confirms token-consuming index builds
The system SHALL run a read-only preflight before starting user-triggered AI-assisted memo search and SHALL ask for user confirmation when the current search scope requires new or refreshed embedding index work.

#### Scenario: AI search starts directly when no index work is needed
- **WHEN** the user triggers AI-assisted memo search for a non-empty query and the current search scope already has fresh embeddings for the active embedding model
- **THEN** the system SHALL start AI-assisted memo search without showing an index token confirmation dialog.

#### Scenario: AI search asks before building embeddings
- **WHEN** the user triggers AI-assisted memo search for a non-empty query and the current search scope requires new or refreshed embeddings for eligible memo chunks
- **THEN** the system SHALL show a confirmation prompt before starting indexing or embedding requests.

#### Scenario: Confirmation shows estimated indexing tokens
- **WHEN** the confirmation prompt is shown
- **THEN** the prompt SHALL include an estimated token count for the required indexing work.

#### Scenario: Cancel keeps keyword search active
- **WHEN** the confirmation prompt is shown and the user cancels
- **THEN** the system SHALL leave the current keyword search state active and SHALL NOT enqueue index jobs, rebuild chunks, or call the embedding provider for indexing.

#### Scenario: Continue starts AI-assisted search
- **WHEN** the confirmation prompt is shown and the user confirms
- **THEN** the system SHALL start AI-assisted memo search and MAY build or refresh the required semantic index according to existing AI search indexing rules.

#### Scenario: Missing embedding configuration keeps existing recovery behavior
- **WHEN** the user triggers AI-assisted memo search without a configured embedding route
- **THEN** the system SHALL NOT show an index token confirmation prompt and SHALL preserve the existing configuration-required recovery state.

### Requirement: AI search index confirmation is localized and informative
The system SHALL render all user-visible AI search index confirmation copy through the existing localization system for every supported app locale.

#### Scenario: Confirmation copy uses active locale
- **WHEN** the AI search index confirmation prompt is shown
- **THEN** the title, explanation, token estimate label, cancel action, and continue action SHALL render localized copy for the active locale.

#### Scenario: Remote embedding warning is explicit
- **WHEN** the active embedding profile uses a remote API backend and the confirmation prompt is shown
- **THEN** the prompt SHALL explain that eligible memo chunks may be sent to the configured embedding model and may consume provider quota or cost.

#### Scenario: Local embedding warning avoids billing claims
- **WHEN** the active embedding profile uses a local API backend and the confirmation prompt is shown
- **THEN** the prompt SHALL explain that the estimated tokens represent local embedding/indexing work without claiming remote provider billing.

#### Scenario: Hard-coded confirmation copy is guarded
- **WHEN** memo list widget or screen code is changed
- **THEN** automated tests or guardrails SHALL fail if known AI search index confirmation English phrases are reintroduced directly in memo list UI code.

### Requirement: AI search index preflight preserves modular boundaries
The system MUST implement AI search index token estimation through reusable service, repository, and provider seams without placing indexing, freshness, chunking, or token-estimation logic in memo list screens or widgets.

#### Scenario: Preflight is read-only
- **WHEN** the system estimates required AI search index work before user confirmation
- **THEN** the preflight MUST NOT enqueue index jobs, invalidate chunks, insert chunks, insert embeddings, or call the embedding provider.

#### Scenario: UI renders and routes user intent only
- **WHEN** memo list UI code is updated for AI search index confirmation
- **THEN** it MUST only request preflight facts through a provider seam, render localized confirmation UI, and route cancel or continue actions.

#### Scenario: State providers do not depend on feature widgets
- **WHEN** state providers are added or changed for AI search index preflight
- **THEN** they MUST NOT introduce new `state -> features` imports.

#### Scenario: Estimation logic reuses AI indexing rules
- **WHEN** AI search index preflight calculates required work
- **THEN** it MUST reuse the same memo eligibility, content hash, chunking, and embedding freshness semantics used by AI-assisted memo search indexing.
