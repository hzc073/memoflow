## ADDED Requirements

### Requirement: iOS and iPadOS commercial capabilities SHALL map through private overlay
iPhone 和 iPadOS 的付费权益 SHALL follow the same Apple commercialization boundary as macOS: private overlay evaluates commercial state and public runtime receives only product-level capability decisions or UI contributions.

#### Scenario: Private overlay evaluates iOS entitlement
- **WHEN** Apple private overlay evaluates iOS or iPadOS commercial state such as free, trial, subscription, buyout, expired, refunded, unavailable, Family Sharing, product, transaction, receipt, or price
- **THEN** it SHALL map that state to product-level `AppCapability` decisions or private UI contributions before public code consumes it
- **AND** public shared models SHALL NOT store the raw commercial state

#### Scenario: Public iOS feature checks paid capability
- **WHEN** a public iOS, iPadOS, or shared Apple feature needs to know whether a paid behavior is available
- **THEN** it SHALL query an `AppCapability` decision or render an approved private contribution
- **AND** it SHALL NOT query StoreKit, product ID, price, receipt, transaction, subscription plan, buyout state, Family Sharing state, or `AccessDecision.source` for business logic

### Requirement: Apple private support and purchase UI SHALL enter through contributions
Apple purchase, restore, supporter, subscription center, and entitlement refresh UI SHALL be contributed by private overlay rather than hardcoded in public Apple platform branches.

#### Scenario: Private Apple purchase UI is available
- **WHEN** Apple private overlay wants to show StoreKit purchase, restore purchase, product display, entitlement refresh, or supporter status on macOS, iPhone, or iPadOS
- **THEN** it SHALL return an approved `SettingsEntryContribution`, support page contribution, route intent, or equivalent private bundle contribution
- **AND** public settings, support, home, and platform code SHALL only render or route to the contribution

#### Scenario: Public Apple build has no private overlay
- **WHEN** the app runs on macOS, iPhone, or iPadOS without Apple private overlay
- **THEN** commercial-only capabilities SHALL remain disabled by default
- **AND** public code SHALL NOT infer from Apple platform alone that paid UI, purchase, restore, or entitlement behavior is available
