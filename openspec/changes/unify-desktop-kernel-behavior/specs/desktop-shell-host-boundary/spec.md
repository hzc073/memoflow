## ADDED Requirements

### Requirement: Desktop shell host SHALL consume desktop kernel policies

The desktop shell host and platform shell implementations SHALL consume desktop kernel policy outputs for route-adjacent layout, titlebar navigation, window command behavior, secondary panes, modal surfaces, and destination shell slots. Feature pages SHALL not own those kernel rules.

#### Scenario: Shell receives shared layout policy
- **WHEN** `DesktopShellHost`, `DesktopDestinationShell`, `WindowsDesktopPageShell`, or `AppleMacosPageShell` resolves navigation mode, sidebar/rail/overlay behavior, titlebar visibility, or secondary pane support
- **THEN** it SHALL use the shared desktop layout/titlebar/surface policy output
- **AND** it SHALL NOT duplicate separate Windows and macOS breakpoint rules for the same semantic behavior

#### Scenario: Shell close control is activated
- **WHEN** a shell-rendered main-window close control is activated
- **THEN** the shell SHALL invoke the desktop window close command seam
- **AND** the resulting lifecycle side effect SHALL be handled by the shared close coordinator or an injected application-level callback

#### Scenario: Feature page participates in desktop shell
- **WHEN** a feature page provides title, actions, body, secondary pane, modal surface, search action, compose action, or preview slots to a desktop shell
- **THEN** the feature page SHALL provide semantic widgets and callbacks
- **AND** the feature page SHALL NOT decide platform-specific desktop kernel behavior that belongs to shell or desktop policy

### Requirement: Desktop shell surface inputs SHALL be honored or explicitly unsupported

Desktop shell implementations SHALL either honor provided secondary pane, modal surface, motion, resize, and barrier inputs or expose a documented unsupported capability/fallback for that platform.

#### Scenario: Secondary pane input reaches platform shell
- **WHEN** a feature passes `secondaryPane`, `secondaryPaneVisible`, `secondaryPaneWidth`, `secondaryPanePresentation`, `secondaryPaneMotionSpec`, or `onSecondaryPaneWidthChanged` through a desktop shell seam
- **THEN** the platform shell SHALL apply the relevant policy output for the current platform
- **AND** it SHALL NOT accept those inputs while ignoring motion or resize behavior without an explicit capability fallback

#### Scenario: Modal input reaches platform shell
- **WHEN** a feature passes `modalSurface`, `modalSurfaceVisible`, `modalBarrierColor`, `modalBarrierBlurSigma`, or `modalSurfaceMotionSpec` through a desktop shell seam
- **THEN** the platform shell SHALL apply modal surface policy consistently for that platform
- **AND** tests SHALL cover both Windows and macOS behavior or an explicit unsupported/fallback path
