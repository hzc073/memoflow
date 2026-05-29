## ADDED Requirements

### Requirement: Desktop kernel policy seams SHALL belong to the desktop common layer

Shared Windows/macOS desktop behavior policy SHALL be classified as desktop common layer work. Platform shell code SHALL consume those policies and render platform-specific chrome, while feature pages SHALL provide semantic intent.

#### Scenario: Shared desktop behavior is added
- **WHEN** a change adds or modifies route motion, layout tiers, secondary pane capability, modal surface behavior, search presentation, compose presentation, preview behavior, window command decisions, or desktop minimum-size policy for both Windows and macOS
- **THEN** the behavior SHALL be classified as desktop common layer policy or an equivalent shared desktop seam
- **AND** platform shell code SHALL be limited to rendering, native integration, and platform-specific mapping

#### Scenario: Platform shell exception is needed
- **WHEN** Windows or macOS needs a platform-specific exception for a desktop kernel behavior
- **THEN** the exception SHALL be documented as a platform shell mapping or unsupported capability
- **AND** the exception SHALL NOT be hidden inside a feature screen or lower-layer shared business helper

#### Scenario: Dependency direction is preserved
- **WHEN** desktop kernel policies are implemented
- **THEN** pure policy files SHALL NOT import `features/*`, `state/*`, `application/*`, `data/*`, or API code
- **AND** lifecycle side effects SHALL remain in `application/desktop`, platform adapters, or explicit composition-root callbacks rather than pure policy helpers
