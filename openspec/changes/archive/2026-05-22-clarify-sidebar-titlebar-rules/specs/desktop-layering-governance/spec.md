## ADDED Requirements

### Requirement: Titlebar navigation context SHALL belong to the platform shell layer
Titlebar title visibility, native window-control avoidance, native close dispatch, and top-level navigation context rules SHALL be treated as platform shell concerns rather than shared business logic or feature-page behavior.

#### Scenario: Change affects titlebar context
- **WHEN** a change decides whether a desktop titlebar shows, hides, relocates, or suppresses a page title based on platform, window chrome, navigation mode, or sidebar visibility
- **THEN** the change MUST be classified as platform shell work

#### Scenario: Change affects native close dispatch
- **WHEN** a change decides whether native window close dismisses a secondary app route or closes/hides the window
- **THEN** the change MUST be classified as platform shell work

#### Scenario: Shared business layer stays platform neutral
- **WHEN** titlebar navigation-context rules are implemented
- **THEN** shared business, data, API, synchronization, repository, and state layers MUST NOT gain imports or flags for macOS traffic lights, Windows caption controls, expanded sidebar title suppression, secondary-route native close dispatch, or other platform shell chrome details

### Requirement: Feature pages SHALL NOT own native window chrome title rules
Feature pages SHALL avoid page-local macOS traffic-light offsets, titlebar magic padding, and duplicated top-leading title suppression logic when participating in a desktop shell.

#### Scenario: Feature page touches desktop page chrome
- **WHEN** a feature page adds or changes desktop title, leading action, trailing action, command bar, drawer destination, or shell slot behavior
- **THEN** it SHALL route titlebar placement and title visibility through the desktop shell host, platform adapter, or equivalent centralized seam

#### Scenario: Feature page touches top-level toolbar height
- **WHEN** a feature page adds or changes macOS expanded-sidebar top-level titlebar, toolbar, AppBar, or body-start spacing
- **THEN** it SHALL route spacer height and titlebar omission behavior through the desktop shell host, platform adapter, or equivalent centralized seam instead of using page-local magic heights

#### Scenario: Feature page touches secondary route dismissal
- **WHEN** a feature page adds or changes secondary desktop route dismissal behavior
- **THEN** it SHALL route macOS native close behavior through the desktop shell host, platform adapter, or equivalent centralized seam

#### Scenario: Coupled area remains equal or better structured
- **WHEN** implementation touches `home`, `settings`, `memos`, or desktop shell code for titlebar navigation context
- **THEN** it MUST remove, isolate, or guard against page-local platform branching so the touched area remains equal or better structured under `evolve_modularity`

### Requirement: Titlebar navigation context guardrails SHALL prevent boundary regressions
The system SHALL protect titlebar navigation context rules with tests, smoke checklists, or architecture guardrails that prevent feature-page drift and lower-layer platform leakage.

#### Scenario: Guardrail scans lower layers
- **WHEN** titlebar navigation context implementation adds helpers, policies, or tests
- **THEN** guardrails SHALL verify that `state`, `application`, `data`, and lower-level shared business files do not depend on feature pages or platform shell chrome details

#### Scenario: Guardrail catches repeated macOS titlebar fixes
- **WHEN** future changes attempt to fix macOS top-leading title overlap from inside an individual top-level feature page
- **THEN** tests, review checklist entries, or architecture guardrails SHALL direct the fix back to the centralized desktop shell or platform adapter policy

#### Scenario: Guardrail catches page-local native close interception
- **WHEN** future changes attempt to intercept macOS native close from inside an individual feature page
- **THEN** tests, review checklist entries, or architecture guardrails SHALL direct the behavior back to the centralized desktop shell or platform adapter policy
