## ADDED Requirements

### Requirement: Apple support center contribution SHALL cover IAP tip and IAP Pro without public commercial branching
Apple support center, subscription center, IAP tip, and IAP Pro entry points SHALL be contributed by private overlay code through approved public seams rather than commercial branches in public settings code.

#### Scenario: Private overlay contributes Apple support center
- **WHEN** a private Apple overlay wants to expose IAP tip, IAP Pro purchase, restore purchase, subscription management, product display, or entitlement refresh
- **THEN** it SHALL provide that support center through `PrivateExtensionBundle`, `SupportMemoFlowContribution`, `SettingsEntryContribution`, or a future approved module-boundary route/action seam
- **AND** public settings code SHALL only render or dispatch the contribution
- **AND** public settings code SHALL NOT branch on StoreKit availability, product ID, price, subscription plan, buyout, Family Sharing, trial, receipt, transaction, or raw entitlement state

#### Scenario: Public shell runs without private support center
- **WHEN** the public repository runs without a private Apple support-center contribution
- **THEN** public defaults SHALL remain free-safe
- **AND** commercial-only capabilities SHALL remain disabled by default
- **AND** existing non-commercial memo workflows SHALL keep their current behavior

### Requirement: IAP tip SHALL not map to product capabilities
Private entitlement mapping SHALL keep voluntary IAP tip purchases separate from `Pro` and feature capability decisions.

#### Scenario: Tip purchase is processed privately
- **WHEN** private StoreKit code processes a tip / coffee support purchase
- **THEN** the private layer MAY record private diagnostic or support acknowledgement state if approved
- **AND** it SHALL NOT map that purchase to `premiumEntitlements`, `aiCustomSummaryTemplates`, `aiSummaryHistory`, `advancedStats`, `desktopNativeCapture`, `appleICloudDriveIntegration`, `appleShortcutsIntegration`, `appleSpotlightIndexing`, or other capability unlocks
- **AND** public shared models SHALL NOT persist raw tip purchase state

### Requirement: Pro purchase SHALL map to capabilities before public consumption
Private Apple purchase and restore flows SHALL map commercial entitlement state into product-level capability decisions before public feature code consumes it.

#### Scenario: Subscription or buyout entitlement is active
- **WHEN** private StoreKit and entitlement code determine that a subscription, buyout, trial, or other approved `Pro` state is active
- **THEN** the private entitlement layer SHALL map it to enabled `AppCapability` decisions for the covered product capabilities
- **AND** public feature code SHALL only consume the resulting `AccessDecision.enabled` or equivalent capability result
- **AND** `AccessDecision.source` SHALL remain diagnostic metadata only and SHALL NOT be used for UI visibility, routing, unlock decisions, or feature flags

#### Scenario: Restore purchase refreshes entitlement
- **WHEN** a user activates restore purchase in the private Apple support center
- **THEN** restore handling SHALL remain inside private StoreKit / entitlement code
- **AND** public code SHALL receive only refreshed capability decisions or a private contribution-rendered result state
- **AND** public code SHALL NOT parse transactions, receipts, product IDs, or purchase errors directly

### Requirement: Apple external support CTA policy SHALL not leak into public capability decisions
External support payment availability for Apple runtimes SHALL NOT be modeled as a public product capability that unlocks business logic.

#### Scenario: Public code asks for commercial capabilities
- **WHEN** public code checks `AppCapability` decisions for Pro or Apple ecosystem features
- **THEN** those decisions SHALL describe product behavior availability only
- **AND** they SHALL NOT encode whether an Apple runtime may show an external Alipay payment CTA
- **AND** external payment CTA policy SHALL be handled by support-surface policy or private overlay routing rules

#### Scenario: Guardrails scan commercial leakage
- **WHEN** architecture or repository guardrails scan public shell and shared public models
- **THEN** they SHALL block StoreKit/IAP implementation details and raw commercial state
- **AND** they SHOULD also block accidental Apple runtime external payment branches in public settings support surfaces unless a documented exception is present
