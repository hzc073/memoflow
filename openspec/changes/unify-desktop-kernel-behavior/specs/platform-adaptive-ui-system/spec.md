## ADDED Requirements

### Requirement: Desktop transient, search, and compose surfaces SHALL use semantic adaptive intent

Desktop transient UI, search, and compose presentation SHALL be selected from semantic intent through adaptive or desktop kernel seams. Feature pages SHALL not create independent Windows/macOS presentation branches for the same desktop task.

#### Scenario: Desktop modal or transient task is presented
- **WHEN** a desktop feature presents an editor, confirmation, utility view, inspector, picker, popover, dialog, sheet, or modal task surface
- **THEN** it SHALL express the semantic task and required behavior through a desktop surface policy, adaptive UI seam, or approved shell slot
- **AND** Windows/macOS renderers SHALL choose platform-appropriate visuals below that seam

#### Scenario: Desktop search is presented
- **WHEN** a desktop feature exposes search from keyboard shortcut, command bar, toolbar, titlebar, or page action
- **THEN** it SHALL express search intent through a shared search presentation seam or feature-specific semantic model
- **AND** it SHALL NOT encode the shared search state machine as a Windows-only header special case unless an explicit platform exception is documented

#### Scenario: Desktop compose is presented
- **WHEN** a desktop feature opens text compose, voice compose result, edit compose, or inline compose
- **THEN** it SHALL resolve the presentation through desktop compose policy, adaptive UI seam, or approved feature-owned semantic presenter
- **AND** Windows/macOS differences SHALL be limited to renderer/chrome choices rather than separate business or route-delegate state machines

#### Scenario: Adaptive UI migration preserves public boundary
- **WHEN** desktop adaptive surface, search, or compose code is added to public shell files
- **THEN** it SHALL NOT introduce subscription, billing, entitlement, receipt, paywall, StoreKit, product ID, price, buyout, private release automation, or `AccessDecision.source` business branching logic
