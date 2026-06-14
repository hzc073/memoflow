## ADDED Requirements

### Requirement: iPhone bottom navigation resolves dynamic colors before alpha
The runtime bottom navigation bar SHALL preserve iOS dynamic color behavior by resolving `CupertinoDynamicColor` against the active `BuildContext` before applying opacity or channel changes.

#### Scenario: Dark system background remains dark after alpha
- **WHEN** `HomeBottomNavShell` renders the iPhone bottom navigation bar in dark mode
- **THEN** the resolved navigation background MUST come from the dark variant of the iOS system background or an app-approved dark surface
- **AND** alpha MUST be applied after resolving the dynamic color for the current context

#### Scenario: Light mode keeps the existing visual intent
- **WHEN** `HomeBottomNavShell` renders the iPhone bottom navigation bar in light mode
- **THEN** the navigation background MAY remain a light translucent surface
- **AND** the bottom safe-area decoration MUST continue to cover the gesture inset

### Requirement: iPhone bottom navigation labels remain readable in night mode
The runtime bottom navigation bar SHALL choose selected and unselected item colors that remain readable on the resolved iPhone night-mode navigation surface.

#### Scenario: Selected item uses a night-readable accent
- **WHEN** an iPhone bottom navigation destination is selected in night mode
- **THEN** its icon and label use a color with visible contrast against the resolved navigation background
- **AND** the selected state remains visually distinct from unselected destinations

#### Scenario: Unselected item remains visible
- **WHEN** an iPhone bottom navigation destination is not selected in night mode
- **THEN** its icon and label remain visible against the resolved navigation background
- **AND** the label does not become hidden because of light surface and light text or dark surface and dark text mismatch

### Requirement: iPhone bottom navigation dark-mode behavior is covered by tests
The implementation SHALL include widget regression coverage for iPhone bottom navigation night-mode colors and safe-area decoration.

#### Scenario: Dark-mode test observes non-light navigation background
- **WHEN** a widget test renders `HomeBottomNavShell` as iPhone with dark theme and bottom safe-area inset
- **THEN** the decorated bottom navigation surface is not resolved as a white or light-mode system background
- **AND** the surface still wraps the bottom safe-area inset

#### Scenario: Dark-mode test observes visible labels
- **WHEN** a widget test renders the configured iPhone bottom navigation destinations in dark mode
- **THEN** destination labels are present
- **AND** their resolved text color is not effectively invisible against the resolved navigation background
