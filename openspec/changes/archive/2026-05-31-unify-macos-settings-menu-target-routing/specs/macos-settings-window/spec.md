## ADDED Requirements

### Requirement: Desktop settings window targets SHALL support pane-local nested destinations
桌面设置窗口 target routing SHALL support both top-level settings panes and pane-local nested settings pages, so macOS settings-like menu commands can land in the same settings shell used by in-window navigation.

#### Scenario: Nested settings target is requested
- **WHEN** the app requests a nested settings target such as templates, location, image bed, image compression, memo toolbar, or desktop shortcuts
- **THEN** the settings window SHALL open or focus
- **AND** it SHALL select the owning pane
- **AND** it SHALL navigate inside that pane to the requested settings page

#### Scenario: Existing nested navigation is reset for a new target
- **GIVEN** the settings window is already open on one pane or nested settings page
- **WHEN** a different settings target is requested
- **THEN** the settings window SHALL switch to the requested owning pane
- **AND** the pane navigator SHALL show the requested target rather than preserving an unrelated previous nested route

#### Scenario: Targeted settings window preserves fallback semantics
- **WHEN** a pane or nested target cannot be routed after the settings window request
- **THEN** the open operation SHALL report a non-opened result or otherwise allow the caller to show fallback
- **AND** the app SHALL NOT silently focus a wrong settings pane

### Requirement: Settings window target routing SHALL be documented and guarded
Settings window target routing SHALL be documented through implementation notes, tests, or guardrails so future settings-like menu commands use the same seam.

#### Scenario: New settings-like command is added
- **WHEN** a new macOS menu command opens a settings page
- **THEN** it SHALL either use a desktop settings window target
- **OR** document why it remains a workflow route or task surface candidate

#### Scenario: Target routing seam remains boundary-safe
- **WHEN** additional settings window targets are added
- **THEN** lower layers SHALL pass stable target values only
- **AND** feature widget construction SHALL remain in settings UI composition
- **AND** the seam MUST NOT add commercial, subscription, entitlement, StoreKit, private overlay, or paid-feature branching logic
