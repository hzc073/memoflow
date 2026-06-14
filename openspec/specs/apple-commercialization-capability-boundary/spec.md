# apple-commercialization-capability-boundary Specification

## Purpose
TBD - created by archiving change apple-commercialization-capability-boundary. Update Purpose after archive.
## Requirements
### Requirement: Public capability boundary
The system SHALL expose Apple commercialization behavior to public runtime code through product-level `AppCapability` decisions only.

#### Scenario: Public code checks product capability
- **WHEN** public feature, state, or application code needs to know whether a Pro behavior is available
- **THEN** it SHALL query a product-level capability decision such as AI template, AI history, advanced stats, desktop native capture, iCloud Drive, Shortcuts/App Intents, or Spotlight
- **AND** it SHALL NOT query subscription plan, product ID, StoreKit transaction, receipt, price, Family Sharing, or buyout state directly

#### Scenario: Public default remains free-safe
- **WHEN** the public repository runs without a private overlay
- **THEN** capability decisions SHALL keep commercial-only capabilities disabled by default
- **AND** base memo creation, reading, editing, local library access, basic import/export, and existing data viewing SHALL remain available

### Requirement: Private entitlement mapping
The system SHALL keep real Apple entitlement state and commercial plan mapping in the private overlay or private packages.

#### Scenario: Private overlay maps entitlement state
- **WHEN** the private overlay evaluates `free`, `trial`, `subscriptionPro`, `buyoutPro`, `expired`, `refunded`, or `unavailable`
- **THEN** it SHALL map that state to product-level capability decisions before public feature code consumes it
- **AND** public shared models SHALL NOT store the raw commercial state

#### Scenario: Subscription and buyout differ without leaking plan logic
- **WHEN** a capability is available to subscription users, buyout users, or both
- **THEN** the private entitlement layer SHALL decide the mapping
- **AND** public feature code SHALL only receive whether the requested capability is enabled

### Requirement: Simulated entitlement mode
The private overlay SHALL support a development and test-only simulated entitlement mode before StoreKit is implemented.

#### Scenario: Simulated state drives capabilities
- **WHEN** a developer selects a simulated entitlement state in the private overlay
- **THEN** the capability decisions SHALL match the selected state for local testing
- **AND** the simulation SHALL cover at least free, trial, subscriptionPro, buyoutPro, expired, refunded, and unavailable

#### Scenario: Simulation does not become public commercial logic
- **WHEN** public repository code is scanned
- **THEN** it SHALL NOT contain private simulation switches, StoreKit fallback unlocks, product IDs, prices, or subscription plan state

### Requirement: AI custom summary template gating
The system SHALL use capability decisions to gate AI custom summary template count and template actions.

#### Scenario: Free user creates first template
- **WHEN** AI custom summary templates are enabled only at the free baseline
- **AND** the user has no custom summary template
- **THEN** the user SHALL be able to create one custom summary template

#### Scenario: Free user reaches template limit
- **WHEN** AI custom summary templates are enabled only at the free baseline
- **AND** the user already has one custom summary template
- **THEN** the system SHALL block creating additional custom summary templates
- **AND** the user SHALL be guided toward the private upgrade entry without public code knowing product IDs or prices

#### Scenario: Pro or buyout user uses multiple templates
- **WHEN** the capability decision enables multiple AI custom summary templates
- **THEN** the user SHALL be able to create, edit, and use multiple custom summary templates

#### Scenario: Expired user keeps template data
- **WHEN** a user loses the capability for multiple AI custom summary templates
- **AND** the user has more templates than the free limit
- **THEN** the system SHALL NOT delete any templates
- **AND** templates above the free active allowance SHALL be viewable but not usable, editable, or copyable
- **AND** locked templates SHALL remain deletable

#### Scenario: Capability restored
- **WHEN** the user regains the capability for multiple AI custom summary templates
- **THEN** all previously locked templates SHALL become usable and editable again

### Requirement: Subscription center contribution
The system SHALL expose subscription or upgrade UI through private bundle settings contributions rather than public shell commercial branches.

#### Scenario: Private bundle contributes subscription entry
- **WHEN** the private overlay wants to expose subscription center, purchase, restore, or upgrade UI
- **THEN** it SHALL return a `SettingsEntryContribution` through the private bundle
- **AND** `settings_screen.dart` SHALL only render the contribution

#### Scenario: Public settings does not branch on commercial state
- **WHEN** `settings_screen.dart` is evaluated
- **THEN** it SHALL NOT import commercial implementations
- **AND** it SHALL NOT branch on subscription, buyout, Family Sharing, trial, product ID, price, StoreKit, or entitlement state

### Requirement: Commercial leakage guardrails
The system SHALL include tests or repository scans that prevent Apple commercial implementation details from entering public shell and shared public models.

#### Scenario: Block high-confidence commercial leakage
- **WHEN** architecture or repository guardrails scan public runtime code
- **THEN** they SHALL fail on StoreKit imports, product IDs, receipt verification logic, purchase / restore implementations, hardcoded commercial prices, or private entitlement implementations outside approved private hooks

#### Scenario: Protect shared public models
- **WHEN** shared public models such as preferences, session, account, update config, or general repositories are scanned
- **THEN** they SHALL NOT contain subscription plan state, buyout state, Family Sharing state, Apple receipt state, or paid-feature persistence

#### Scenario: Keep diagnostic metadata non-authoritative
- **WHEN** public Dart code references `AccessDecision.source`
- **THEN** guardrails SHALL prevent using it for UI visibility, routing, unlocking, feature flags, or other business decisions

### Requirement: Apple capability scope
The system SHALL distinguish desktop-native enhancements from Apple ecosystem enhancements.

#### Scenario: Desktop-native capability is not Apple-exclusive
- **WHEN** a feature such as menu bar capture, global quick input, floating capture, or native window enhancement is specified
- **THEN** it SHALL be treated as desktop-native enhancement that may have Windows and macOS implementations
- **AND** it SHALL NOT be described as exclusively Apple unless it depends on Apple-only APIs

#### Scenario: Apple ecosystem capability remains Apple-specific
- **WHEN** a feature depends on iCloud Drive, Shortcuts/App Intents, Spotlight, or another Apple-only API
- **THEN** it SHALL be modeled as an Apple ecosystem capability
- **AND** public repository code SHALL still avoid StoreKit, product, and entitlement implementation details

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

