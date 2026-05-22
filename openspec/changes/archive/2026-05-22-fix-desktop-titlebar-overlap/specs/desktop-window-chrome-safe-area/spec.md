## ADDED Requirements

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
