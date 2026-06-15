## ADDED Requirements

### Requirement: Settings SHALL expose a unified Support MemoFlow entry
设置首页 SHALL expose one user-facing entry named “支持 MemoFlow” or localized equivalent for project support, replacing the previous primary “充电站” presentation.

#### Scenario: User opens support from settings
- **WHEN** 用户在设置首页点击支持入口
- **THEN** the app SHALL navigate to an independent support page or equivalent full support surface
- **AND** it SHALL NOT open the legacy donation dialog as the primary support experience
- **AND** the support surface SHALL communicate voluntary project support without promising feature unlocks or service access

#### Scenario: Existing charging station wording is retired as primary label
- **WHEN** settings home entries are rendered
- **THEN** “充电站” SHOULD NOT be the primary entry label
- **AND** playful charging or coffee copy MAY remain only as secondary copy, illustration text, or non-essential flavor text

### Requirement: Desktop settings window SHALL expose Support MemoFlow
Windows 和 macOS 的桌面设置窗口 SHALL expose a platform-neutral “支持 MemoFlow” entry or pane that renders the same support surface as settings home.

#### Scenario: Desktop user opens support from desktop settings window
- **WHEN** the desktop settings window is rendered on Windows or macOS
- **THEN** it SHALL expose a user-facing “支持 MemoFlow” or localized equivalent entry
- **AND** selecting that entry SHALL render `SupportMemoFlowScreen` or an equivalent full support surface inside the desktop settings window
- **AND** the desktop support surface SHALL use `showBackButton: false` or equivalent desktop pane chrome semantics
- **AND** it SHALL NOT be implemented as a Windows-only UI branch

#### Scenario: Desktop settings target routes directly to support
- **WHEN** a desktop settings window target for support is requested
- **THEN** the target SHALL resolve through a generic desktop support target such as `DesktopSettingsWindowTarget.supportMemoFlow`
- **AND** it SHALL route to the same support surface used by the visible desktop entry
- **AND** macOS SHALL NOT infer commercial purchase UI from platform alone when no private support contribution exists

### Requirement: Public support page SHALL remain commercial-free
公开仓的 “支持 MemoFlow” 页面 SHALL provide public project-support narrative and voluntary appreciation fallback without embedding commercial purchase logic.

#### Scenario: Public build renders support page
- **WHEN** the public repository runs without private overlay
- **THEN** the support page SHALL render a public appreciation fallback on non-Apple runtimes or non-commercial support explanation on Apple runtimes
- **AND** the initial non-Apple fallback external support link SHALL be `https://qr.alipay.com/tsx16856ygfke5rugz1ao4a`
- **AND** non-Apple phone and tablet surfaces SHALL use the external support link as the primary support action
- **AND** non-Apple desktop surfaces SHALL show a generated QR code based on the external support link instead of opening the support link as the primary support action
- **AND** Apple runtimes SHALL NOT show the external support link, generated QR code, or external payment calls to action unless a future approved exception change explicitly allows it
- **AND** it MAY link to the official Beijing Han Hong Love Charity Foundation website for transparency
- **AND** it SHALL NOT show public donation QR assets such as `assets/images/donation_qr.png` as the support page support method
- **AND** it SHALL NOT show StoreKit purchase, restore purchase, product ID, subscription group, receipt validation, entitlement state, Family Sharing state, buyout state, trial state, or hardcoded commercial price

#### Scenario: Public appreciation remains voluntary
- **WHEN** Windows, Android, Linux, web, or another non-Apple build renders the public appreciation fallback
- **THEN** appreciation copy SHALL present support as voluntary project maintenance support
- **AND** appreciation copy SHALL NOT promise digital feature unlocks, paid capabilities, premium state, Apple-specific entitlement, badge unlocks, or service access in exchange for appreciation
- **AND** unsupported or unselected appreciation SHALL NOT block base recording, editing, reading, local library access, or basic import/export

#### Scenario: Public-good commitment is shown
- **WHEN** the public appreciation page includes public-good copy
- **THEN** it MAY state that if the project generates profit, MemoFlow will donate part of it to the Beijing Han Hong Love Charity Foundation and publish records
- **AND** it SHALL NOT promise a fixed percentage, fixed amount, fixed donation schedule, or fixed trigger condition
- **AND** it SHOULD provide a public-good record link, initially `https://memoflow.app/support/public-good` or an equivalent official website location

### Requirement: Apple supporter commercial experience SHALL be provided by private overlay
Apple 平台的“成为支持者”商业体验 SHALL be implemented in private overlay code, not in the public repository shell.

#### Scenario: Private Apple overlay contributes support experience
- **WHEN** `memoflow-macos-private` or another approved private overlay is active on macOS, iOS, or iPadOS
- **THEN** it MAY contribute Apple supporter UI for StoreKit purchase, restore purchase, product display, entitlement refresh, and Apple platform enhancement explanation through an approved private bundle seam
- **AND** public settings code SHALL only render or route to the contributed surface
- **AND** public settings code SHALL NOT import private StoreKit modules or branch on raw commercial state

#### Scenario: Public Apple build has no private overlay
- **WHEN** the app runs on an Apple platform without private commercial overlay
- **THEN** public support behavior SHALL remain free-safe
- **AND** it SHALL render static non-commercial support explanation
- **AND** it SHALL NOT render external support links, generated QR codes, or external payment calls to action
- **AND** it SHALL NOT infer from Apple platform alone that commercial purchase UI is available

### Requirement: Support page contribution seam SHALL not leak commercial state
Any future seam that lets private code customize the support page SHALL expose UI contribution or route intent only, not raw commercial state.

#### Scenario: Public page asks for private support contribution
- **WHEN** the support page requests optional private support content
- **THEN** the public interface SHALL return an optional contribution, action, or route intent
- **AND** the public interface SHALL NOT expose raw `free`, `trial`, `subscriptionPro`, `buyoutPro`, `expired`, `refunded`, `unavailable`, product ID, price, transaction, receipt, or StoreKit objects

#### Scenario: Contribution is absent
- **WHEN** no private support contribution is returned
- **THEN** the support page SHALL render the public donation fallback on non-Apple runtimes and free-safe explanation on Apple runtimes
- **AND** it SHALL remain usable on Windows, Android, Linux, web, and public Apple builds through the appropriate non-Apple fallback or Apple free-safe explanation

### Requirement: Support page visual direction SHALL be clean and platform-appropriate
“支持 MemoFlow” 页面 SHALL use a clean, restrained, Apple-inspired visual direction while staying consistent with the app settings system.

#### Scenario: Support page visual hierarchy is rendered
- **WHEN** the support page is displayed
- **THEN** it SHOULD use generous whitespace, platform default typography, subtle surfaces, restrained color, and clear hierarchy
- **AND** it SHOULD feel consistent with settings semantic components and platform adaptive UI
- **AND** it SHOULD avoid heavy scrapbook styling, dense watercolor decoration, oversized marketing hero sections, or page-local styling that conflicts with the settings system

#### Scenario: Platform-specific layout is needed
- **WHEN** support page layout differs across phone, tablet, macOS, Windows, Android, or future iOS / iPadOS targets
- **THEN** those differences SHALL be expressed through settings/platform seams or approved semantic components
- **AND** the implementation SHALL NOT create duplicated platform feature trees such as `features_ios/`, `features_macos/`, or `features_windows/`

### Requirement: Support entry SHALL preserve public/private and modularity boundaries
Support page implementation SHALL preserve current public/private split and `evolve_modularity` constraints.

#### Scenario: Public support code is scanned
- **WHEN** files under public settings, private hooks interfaces, module boundaries, shared models, session state, preferences, or app shell are reviewed
- **THEN** they MUST NOT include subscription, billing, entitlement, receipt, paywall, StoreKit, product ID, hardcoded commercial price, buyout, Family Sharing, private release automation, or `AccessDecision.source` business branching logic

#### Scenario: Settings support surface is implemented
- **WHEN** future implementation touches settings support pages or contribution seams
- **THEN** it SHALL NOT introduce new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies
- **AND** it SHOULD add or tighten guardrails that prevent public commercial leakage or support-page boundary regressions
