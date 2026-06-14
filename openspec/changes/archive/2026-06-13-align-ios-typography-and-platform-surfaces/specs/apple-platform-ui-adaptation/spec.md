## ADDED Requirements

### Requirement: Apple mobile typography SHALL respect platform system text behavior
Apple mobile UI adaptation SHALL render iPhone and iPadOS app chrome with platform system typography semantics by default. Persisted `fontFamily` and `fontFile` values from device preferences, migration, or sync MUST NOT be applied to the effective iOS/iPadOS app chrome theme unless a later OpenSpec change explicitly introduces an iOS-supported bundled font strategy.

#### Scenario: iPhone ignores migrated desktop font family
- **WHEN** the app runs on iPhone and device preferences contain a non-empty `fontFamily` or `fontFile` that originated from another platform
- **THEN** the effective app theme SHALL use the Apple platform system font for app chrome
- **AND** the persisted `fontFamily` and `fontFile` values SHALL remain stored for platforms that support them

#### Scenario: iPadOS uses the same typography rule
- **WHEN** the app runs on iPadOS and the viewport resolves to `PlatformTarget.iPad`
- **THEN** the effective app theme SHALL use the same Apple mobile system-font behavior as iPhone
- **AND** implementation MUST NOT create a duplicate iPad-only preference or page tree

#### Scenario: Non-Apple font behavior is preserved
- **WHEN** the app runs on Android, Windows, Linux, or another supported non-iOS target with an available custom or system font preference
- **THEN** this Apple adaptation SHALL NOT remove that platform's existing effective font behavior

### Requirement: Apple mobile text scaling SHALL preserve system accessibility scaling
Apple mobile UI adaptation SHALL preserve iOS/iPadOS system text scaling semantics when applying MemoFlow font-size preferences.

#### Scenario: iPhone system text scale is retained
- **WHEN** the app runs on iPhone and the system `MediaQuery.textScaler` is greater or smaller than standard size
- **THEN** the effective app `MediaQuery.textScaler` SHALL preserve the system scaler contribution
- **AND** MemoFlow `AppFontSize` SHALL be applied as an additional app preference rather than replacing the system scaler outright

#### Scenario: Standard app font size does not suppress Dynamic Type
- **WHEN** the app runs on iPhone with `AppFontSize.standard`
- **THEN** the effective text scaler SHALL continue to reflect the system text-size setting
- **AND** it MUST NOT collapse to a fixed `TextScaler.linear(1.0)` solely because the app preference is standard

### Requirement: Apple mobile UI chrome SHALL avoid reader-oriented global line height
Apple mobile app chrome SHALL avoid applying reader-oriented `AppLineHeight` values globally to navigation, settings rows, buttons, tab labels, list chrome, and other high-perception UI text.

#### Scenario: UI chrome is rendered on iPhone
- **WHEN** a migrated Apple mobile surface renders page chrome, grouped settings rows, primary actions, navigation labels, picker labels, or bottom navigation labels
- **THEN** those UI text surfaces SHALL use platform-appropriate or theme-default line height behavior
- **AND** they MUST NOT be forced to use the user's reader/content line-height preference by the global app theme

#### Scenario: Reader content can still use line-height preference
- **WHEN** memo body text, collection reader content, or another explicit reading surface renders user content
- **THEN** it MAY continue to use the existing user-selected content line-height preference
- **AND** the implementation SHALL keep that content behavior separate from Apple mobile UI chrome behavior

### Requirement: Apple settings font entry SHALL avoid invalid system-font selection
Apple mobile settings adaptation SHALL avoid presenting a system-font selection UI that cannot produce selectable iOS fonts.

#### Scenario: Preferences opens on iPhone
- **WHEN** the user opens Preferences on iPhone
- **THEN** the font setting SHALL either be hidden, disabled, or shown as a non-misleading system-default state
- **AND** tapping it MUST NOT open a picker whose only outcome is an empty iOS system-font list

#### Scenario: Preferences opens on iPadOS
- **WHEN** the user opens Preferences on iPadOS
- **THEN** the font setting SHALL follow the same Apple mobile font-entry behavior as iPhone
- **AND** it SHALL NOT introduce a separate iPad-only settings screen

#### Scenario: Desktop font picker remains available
- **WHEN** the user opens Preferences on Windows, macOS, Linux, or another platform where `SystemFonts.listFonts()` can return selectable fonts
- **THEN** the existing font picker behavior SHALL remain available unless that platform's own requirements say otherwise

### Requirement: Apple typography adaptation SHALL preserve public-shell boundaries
Apple mobile typography and surface adaptation SHALL remain limited to public presentation behavior and SHALL preserve platform adapter dependency direction.

#### Scenario: Apple typography code is added or changed
- **WHEN** code for Apple typography, font-entry capability, text scaling, line-height scope, shell theme, settings surface, or platform policy is added or changed
- **THEN** it MUST NOT include subscription, billing, entitlement, receipt, paywall, StoreKit, product ID, price, private overlay, or `AccessDecision.source` business branching logic

#### Scenario: Platform adapter remains layer-safe
- **WHEN** files under `memos_flutter_app/lib/platform` are added or changed for this typography adaptation
- **THEN** they MUST NOT import `features/*`, `state/*`, `application/*`, or `data/*`
- **AND** any required exception MUST be explicitly documented in OpenSpec and guarded by tests before implementation
