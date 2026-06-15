## ADDED Requirements

### Requirement: Apple runtime support SHALL use private IAP support center
iPhone、iPad 和 macOS 运行时 SHALL 使用 private overlay 提供的 IAP 支持中心作为“支持 MemoFlow”的主要支持/付款入口；没有 private contribution 时 SHALL 显示 free-safe 支持说明而不是外部付款入口。

#### Scenario: Apple user opens Support MemoFlow with private IAP center
- **WHEN** 用户在 iPhone、iPad 或 macOS 运行时打开“支持 MemoFlow”
- **AND** an approved private IAP support center contribution is available
- **THEN** the app SHALL route to a private IAP support center contribution or equivalent private support route
- **AND** the route SHALL be provided through an approved private seam such as `PrivateExtensionBundle` / `SupportMemoFlowContribution`
- **AND** public settings code SHALL NOT construct StoreKit purchase UI, product UI, price UI, restore purchase UI, or entitlement UI directly

#### Scenario: Public Apple runtime has no private IAP support center
- **WHEN** the public repository runs on an Apple platform without private overlay
- **THEN** the support page SHALL remain buildable and usable through free-safe public support explanation
- **AND** it SHALL NOT infer from Apple platform alone that IAP purchase UI is available
- **AND** it SHALL NOT show external Alipay links, Alipay QR codes, or external payment calls to action

### Requirement: Apple IAP tip SHALL be voluntary support without entitlement
Apple 版“打赏开发者”、“请喝咖啡”或 equivalent voluntary support SHALL be modeled as IAP tip support that does not unlock product capabilities.

#### Scenario: User buys an IAP tip
- **WHEN** an Apple App Store user purchases a tip / coffee support item
- **THEN** the purchase SHALL be treated as voluntary project support
- **AND** it SHALL NOT enable `Pro`, `premiumEntitlements`, `subscriptionCenter`, Apple ecosystem features, or any other feature capability by itself
- **AND** the tip SHALL NOT be required for existing non-commercial memo workflows

#### Scenario: IAP tip copy is rendered
- **WHEN** the IAP support center displays tip / coffee support copy
- **THEN** the copy SHALL present the action as voluntary project maintenance support
- **AND** the copy SHALL NOT promise digital feature unlocks, service access, supporter-only state, entitlement state, badges, or routing privileges in exchange for the tip

### Requirement: Apple IAP Pro SHALL unlock enhancements only through private entitlement mapping
Apple 版 `Pro` 功能增强 SHALL be implemented through private StoreKit products and private entitlement mapping to product-level `AppCapability` decisions.

#### Scenario: Pro purchase grants capabilities
- **WHEN** a private Apple StoreKit purchase or restored transaction grants a valid `Pro` entitlement
- **THEN** the private entitlement layer SHALL map the entitlement to approved `AppCapability` decisions
- **AND** public feature code SHALL consume only capability decisions
- **AND** public feature code SHALL NOT read product ID, price, subscription group, transaction, receipt, Family Sharing, buyout, trial, refunded, expired, or raw entitlement state

#### Scenario: Pro entitlement expires or is unavailable
- **WHEN** a user's `Pro` entitlement expires, is refunded, or cannot be verified
- **THEN** previously created user data SHALL remain readable and exportable according to the free baseline
- **AND** newly gated `Pro` creation, automation, or enhancement actions MAY be disabled through capability decisions
- **AND** the user SHALL have a private support-center route to restore purchase or understand the current state

### Requirement: Apple runtime SHALL not show external Alipay payment CTA by default
iPhone、iPad 和 macOS 运行时 SHALL NOT show external Alipay links, Alipay QR codes, or other external payment calls to action for support by default, including debug, local public builds, TestFlight preparation paths, and App Store distributed builds.

#### Scenario: Apple support explanation is rendered
- **WHEN** an Apple runtime renders public appreciation explanation or public-good explanation
- **THEN** it SHALL NOT show `https://qr.alipay.com/tsx16856ygfke5rugz1ao4a` as a payment CTA
- **AND** it SHALL NOT render an Alipay QR code as a support payment method
- **AND** it MAY route the user back to an IAP tip action when private IAP contribution exists or display non-payment explanatory copy

#### Scenario: Approved external purchase exception exists
- **WHEN** a future change receives an approved Apple entitlement, storefront-specific policy path, or explicit review decision for external purchase links
- **THEN** that exception SHALL be documented in a separate OpenSpec change
- **AND** the implementation SHALL gate the external CTA by the approved exception rules rather than enabling it in Apple runtime by default

#### Scenario: Non-Apple public build renders fallback
- **WHEN** Android, Windows, Linux, web, or another approved non-Apple public build renders public appreciation fallback
- **THEN** they MAY use the public external support URL and generated desktop QR behavior
- **AND** they MAY show the Beijing Han Hong Love Charity Foundation official link and public-good record link
- **AND** the fallback SHALL remain voluntary and SHALL NOT promise digital feature unlocks or service access

### Requirement: Public-good explanation SHALL remain a project commitment, not in-app charity collection
公益说明 SHALL describe MemoFlow's project-level commitment and transparent records without presenting Apple IAP products as direct charity donations.

#### Scenario: Public-good copy is shown with support products
- **WHEN** support or IAP pages mention public-good commitments
- **THEN** they MAY state that if the project generates profit, MemoFlow intends to use part of that profit for public-good causes or public-good-aligned projects
- **AND** they SHALL NOT promise a fixed percentage, fixed amount, fixed donation schedule, or fixed trigger condition for public-good spending
- **AND** they SHALL NOT present an Apple IAP product as a direct donation from the user to a charity or fundraiser

#### Scenario: Public-good record link is provided
- **WHEN** the support surface provides public-good transparency
- **THEN** it SHOULD link to an official public-good record location such as `https://memoflow.app/support/public-good`
- **AND** the record SHOULD distinguish project-level public-good actions, recipients, dates, and amount or amount range when available without implying a fixed future commitment

### Requirement: Public appreciation surface SHALL be independently routable and channel-safe
公开赞赏说明 SHALL be available as an independently routable support surface so private IAP pages can link to explanation without re-entering the private IAP main section.

#### Scenario: Private IAP page opens appreciation explanation
- **WHEN** a private IAP support center opens “其他支持方式”, “打赏说明”, or equivalent appreciation explanation
- **THEN** the app SHALL show a public appreciation explanation surface rather than recursively returning to the private IAP support center
- **AND** the surface SHALL apply the current channel's payment CTA policy
- **AND** Apple runtimes SHALL keep external Alipay payment CTA hidden by default

#### Scenario: Public fallback is opened directly
- **WHEN** a non-Apple public build opens the public appreciation surface directly
- **THEN** the surface MAY show the public support URL, generated desktop QR code, mobile external-link action, foundation official link, and public-good record link according to platform experience
- **AND** it SHALL explain that support is voluntary without promising feature unlocks or service access

#### Scenario: Apple public explanation is opened directly
- **WHEN** an Apple runtime opens the public appreciation surface directly without private IAP contribution
- **THEN** the surface SHALL show non-payment support explanation and public-good explanation only
- **AND** it SHALL NOT show the public support URL, generated QR code, mobile external-link action, or any other external payment CTA

### Requirement: Apple IAP support rules SHALL preserve public/private and modularity boundaries
Apple IAP support implementation SHALL preserve the public/private split and `evolve_modularity` constraints.

#### Scenario: Public repository is scanned
- **WHEN** public runtime code, shared public models, settings shell, private hook interfaces, module boundaries, or architecture guardrails are reviewed
- **THEN** they MUST NOT include StoreKit implementation, IAP plugin dependency, product ID, price, receipt validation, transaction processing, restore purchase implementation, raw entitlement state, subscription state, buyout state, Family Sharing state, paywall implementation, or external Apple payment branching
- **AND** any public support-page seam SHALL expose UI contribution, route intent, action intent, or capability decision only

#### Scenario: Support implementation touches coupled settings surfaces
- **WHEN** implementation changes support settings surfaces or private contribution seams
- **THEN** it SHALL NOT introduce new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies
- **AND** it SHOULD extract shared public appreciation logic into a stable feature-local or module-boundary seam instead of hiding reused business rules in screen-local private widgets
