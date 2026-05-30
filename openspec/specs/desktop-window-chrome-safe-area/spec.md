# desktop-window-chrome-safe-area Specification

## Purpose
TBD - created by archiving change fix-desktop-titlebar-overlap. Update Purpose after archive.
## Requirements
### Requirement: Desktop window chrome safe area SHALL reserve native window controls
The system SHALL reserve platform-specific window-control areas before rendering desktop titlebar, toolbar, navigation, or top-leading command content.

#### Scenario: macOS native traffic lights are reserved
- **WHEN** a Flutter desktop window runs on macOS with native traffic lights visible and content allowed to draw into the titlebar region
- **THEN** titlebar, toolbar, navigation, and top-leading command content SHALL be laid out outside the traffic-light reserved area

#### Scenario: Settings subwindow title avoids traffic lights
- **WHEN** the desktop settings window runs on macOS
- **THEN** the visible settings title, leading navigation affordances, and first interactive controls MUST NOT overlap native red/yellow/green window controls

#### Scenario: Main window shell avoids traffic lights
- **WHEN** the main desktop shell runs on macOS
- **THEN** the sidebar, toolbar title, quick actions, and top-leading navigation content MUST NOT overlap native red/yellow/green window controls

### Requirement: Window chrome metrics SHALL be centralized
The system SHALL expose desktop window chrome reserved areas through a shell, platform adapter, or desktop helper seam instead of duplicating raw padding values in feature pages.

#### Scenario: Feature page provides semantic content
- **WHEN** a feature page provides a title, leading action, trailing action, command bar, or body content for a desktop shell
- **THEN** the feature page SHALL NOT need to know macOS traffic-light positions or Windows caption-control geometry

#### Scenario: Helper remains lower-layer safe
- **WHEN** a window chrome safe-area helper, adapter, or shared widget is added or changed
- **THEN** it MUST NOT import `features/*`, `state/*`, `application/*`, or `data/*`

### Requirement: Non-macOS platforms SHALL preserve their existing window control behavior
The system SHALL apply macOS traffic-light reserved insets only to macOS chrome modes that need them, while preserving Windows, Linux, mobile, and web layout behavior.

#### Scenario: Windows frameless shell keeps Windows control rules
- **WHEN** the app runs in a Windows frameless desktop shell
- **THEN** it SHALL use Windows caption-control and drag-region behavior rather than macOS traffic-light leading inset

#### Scenario: Mobile safe areas are unchanged
- **WHEN** the same feature content runs on iOS, Android, or narrow mobile layouts
- **THEN** the desktop window chrome safe-area rules SHALL NOT introduce extra desktop titlebar spacing

### Requirement: Window chrome safe area SHALL be verifiable
The system SHALL include focused verification for desktop chrome safe-area behavior where the app draws content into native or custom titlebar regions.

#### Scenario: macOS titlebar layout is tested
- **WHEN** a macOS titlebar, toolbar, or settings subwindow chrome path is changed
- **THEN** focused widget tests, layout tests, smoke checklist entries, or architecture guardrails SHALL verify that top-leading content remains outside the native traffic-light reserved area

#### Scenario: Regression guard covers central seam
- **WHEN** a centralized window chrome safe-area helper is changed
- **THEN** tests or guardrails SHALL verify both macOS reserved-inset behavior and at least one non-macOS fallback behavior

### Requirement: Desktop task window roots SHALL consume shared chrome safe area

Desktop task window roots SHALL use a shared desktop window chrome safe-area rule before rendering top-level title, navigation, toolbar, status, or top-leading content near platform-owned window controls.

#### Scenario: macOS task window root renders a title
- **WHEN** a desktop task window root is rendered on macOS with native traffic lights visible
- **THEN** the root title, leading navigation affordance if present, toolbar, status text, and first top-leading interactive controls SHALL be laid out outside the native traffic-light reserved area
- **AND** the implementation SHALL use the shared desktop chrome safe-area seam or an equivalent shell-level wrapper
- **AND** the implementation SHALL NOT rely on feature-page-local magic padding to avoid the traffic lights.

#### Scenario: Share task window root uses native close semantics
- **WHEN** the share task window root consumes desktop chrome safe-area spacing
- **THEN** the spacing SHALL only reserve layout space for native platform controls
- **AND** it SHALL NOT introduce an App-owned generic close button
- **AND** it SHALL NOT introduce an App-owned generic cancel button
- **AND** native close SHALL remain the cancellation mechanism for the current share task.

#### Scenario: Non-macOS task window root is rendered
- **WHEN** a desktop task window root is rendered on Windows or Linux
- **THEN** it SHALL use the shared desktop chrome safe-area policy for that platform if native or custom caption controls can overlap Flutter content
- **AND** it SHALL NOT apply macOS traffic-light leading inset unless the platform chrome mode explicitly requires equivalent leading reserved space.

### Requirement: Feature roots SHALL delegate window-control avoidance to desktop shell seams

Feature roots participating in a desktop shell or desktop task window SHALL express semantic title, navigation, task-root state, actions, and body content while delegating platform window-control geometry to a shared desktop chrome seam.

#### Scenario: Feature page provides top-level chrome content
- **WHEN** a feature page or task root provides a title, Back affordance, command bar, status block, or top-leading action
- **THEN** it SHALL pass that content through an approved desktop chrome shell, frame, adapter, or policy when the content can appear near native window controls
- **AND** it SHALL NOT encode macOS traffic-light coordinates, Windows caption-control widths, or Linux window-control assumptions in feature-specific layout code.

#### Scenario: Existing settings window remains stable
- **WHEN** this change standardizes desktop task window chrome safe-area participation
- **THEN** it SHALL NOT redesign settings page/window behavior solely for this rule
- **AND** future settings-window chrome changes SHALL continue to reuse the shared desktop chrome safe-area seam or explicitly document why the native frame makes the seam unnecessary.

### Requirement: Desktop chrome safe-area participation SHALL be guarded

The system SHALL include focused verification or guardrails that make desktop task window chrome safe-area participation discoverable and prevent regressions toward page-local titlebar padding.

#### Scenario: Task window chrome path is changed
- **WHEN** a desktop task window root, shell, or chrome wrapper is added or changed
- **THEN** focused widget tests, layout tests, smoke checklist entries, or architecture guardrails SHALL verify that macOS top-leading content remains outside the native traffic-light reserved area
- **AND** at least one non-macOS behavior SHALL be verified or explicitly documented as unchanged.

#### Scenario: Shared chrome seam is changed
- **WHEN** the shared desktop chrome safe-area helper, shell, adapter, or policy is changed
- **THEN** tests or guardrails SHALL verify that the seam remains lower-layer safe
- **AND** the seam SHALL NOT import `features/*`, `application/*`, `state/*`, or `data/*`.

### Requirement: Desktop task surfaces SHALL avoid native window controls through shared chrome seams

桌面任务表面 SHALL use shared desktop chrome safe-area seams or platform dialog geometry so title, close/cancel affordances, first interactive controls, and action bars do not overlap native or custom window controls. Feature pages SHALL NOT solve this by hardcoding macOS traffic-light coordinates or platform-specific padding.

#### Scenario: macOS task surface is shown from the main window
- **WHEN** a desktop task surface is shown on macOS from a main window that has visible native traffic lights
- **THEN** the task title, close/cancel affordance, and first interactive controls SHALL be laid out outside the traffic-light reserved area
- **AND** the task surface SHALL NOT place a feature-owned back button under the red/yellow/green controls

#### Scenario: Windows or Linux task surface is shown
- **WHEN** a desktop task surface is shown on Windows or Linux
- **THEN** the surface SHALL preserve the platform's existing window-control behavior
- **AND** it SHALL NOT apply macOS-only traffic-light leading inset unless that platform chrome mode explicitly declares an equivalent reserved area

#### Scenario: Feature task content is migrated
- **WHEN** a feature task screen is migrated into a shared desktop task surface
- **THEN** the feature task content SHALL provide semantic content and actions
- **AND** the shared surface or shell SHALL own native window-control avoidance

