## ADDED Requirements

### Requirement: macOS settings window SHALL be treated as a high-perception Apple UI surface
The Apple platform UI adaptation SHALL treat the macOS settings window as a high-perception Apple UI surface that must look and behave intentionally on macOS while reusing shared settings state and pages.

#### Scenario: macOS settings surface is opened
- **WHEN** the user opens settings on macOS
- **THEN** the system SHALL prefer a macOS-appropriate independent settings window or equivalent native-feeling settings surface
- **AND** it SHALL NOT rely on an Android-style drawer transition as the primary macOS settings experience

#### Scenario: Settings window cannot be opened
- **WHEN** the macOS independent settings window cannot be opened
- **THEN** the fallback settings page SHALL still use existing platform page, route, grouped list, and Apple shell adaptations where available

### Requirement: macOS settings adaptation SHALL avoid duplicate feature page trees
The macOS settings adaptation SHALL reuse existing feature screens, platform adapters, and settings composition seams instead of creating a parallel Apple settings feature tree.

#### Scenario: macOS-specific settings behavior is added
- **WHEN** macOS-specific settings window behavior, chrome, routes, or entry handling is added
- **THEN** it SHALL be implemented through platform, desktop window, shell, or composition seams
- **AND** it MUST NOT create a full duplicate `features_macos/`, `features_ios/`, or Apple-only settings page hierarchy

### Requirement: macOS settings adaptation SHALL preserve public/private boundaries
The macOS settings adaptation SHALL remain public-shell safe and SHALL NOT introduce commercial branching into shared Apple UI or settings code.

#### Scenario: macOS settings UI code is changed
- **WHEN** macOS settings UI, shell, menu, route, or window code is added or changed in the public repository
- **THEN** it MUST NOT branch on subscription, paid feature, entitlement, receipt, product, price, Family Sharing, StoreKit, or `AccessDecision.source`
