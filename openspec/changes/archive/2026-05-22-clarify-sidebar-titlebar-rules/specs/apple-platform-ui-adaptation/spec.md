## ADDED Requirements

### Requirement: macOS shell SHALL avoid redundant top-leading titles in expanded sidebar mode
The macOS Apple shell SHALL treat the expanded sidebar selected state as the page context for top-level drawer destinations and SHALL NOT place duplicate destination titles in the native traffic-light titlebar area.

#### Scenario: Top-level destination uses sidebar context
- **WHEN** the app runs on macOS, the main shell shows an expanded sidebar, and the selected page is a top-level drawer destination such as memos, explore, review, collections, resources, tags, stats, settings, or about
- **THEN** the macOS shell SHALL use the sidebar selected state as the current-page indicator instead of rendering the same destination label in the top-leading titlebar region

#### Scenario: Expanded sidebar navigation remains vertically stable
- **WHEN** the app runs on macOS with an expanded sidebar and switches between top-level drawer destinations that omit duplicated titlebar content
- **THEN** the macOS shell SHALL keep a consistent titlebar or toolbar spacer height so the sidebar menu position does not jump between destinations

#### Scenario: Apple shell still supports compact context
- **WHEN** the app runs on macOS with rail, overlay, narrow, or otherwise hidden navigation labels
- **THEN** the macOS shell SHALL allow the current destination title to appear only in a region that is outside native traffic-light reserved space

#### Scenario: Secondary Apple pages preserve task titles
- **WHEN** a macOS page represents a secondary task, detail, editor, subwindow, modal surface, or route with back semantics
- **THEN** the Apple shell SHALL preserve meaningful title or navigation context outside native window-control reserved space

### Requirement: macOS main-window close control SHALL dismiss secondary routes
The macOS Apple shell SHALL use the native red close control to dismiss secondary routes inside the main app window before applying normal root-window close or hide behavior.

#### Scenario: Secondary route uses native close as route dismissal
- **WHEN** the macOS main window displays a pushed secondary route such as release notes, diagnostics, detail, editor, or settings subsection and that route can be popped
- **THEN** activating the native red close control SHALL pop that route and return to the previous app context while keeping the main window open

#### Scenario: Root route keeps native window behavior
- **WHEN** the macOS main window displays a root or top-level route
- **THEN** activating the native red close control SHALL keep the normal macOS window close or hide behavior

#### Scenario: App-level route dismissal controls are omitted
- **WHEN** the macOS main window displays a secondary route whose dismissal is handled by native close dispatch
- **THEN** the Apple shell SHALL NOT render an additional app-level back button, close button, or done button for that route

### Requirement: Apple titlebar context SHALL use centralized shell policy
The macOS Apple shell SHALL derive title visibility from a centralized desktop shell or platform adapter policy rather than feature-page-specific traffic-light padding or page-by-page title suppression.

#### Scenario: Feature page does not own traffic-light decisions
- **WHEN** a feature page passes `leadingTitle`, command-bar content, or navigation content to a macOS desktop shell
- **THEN** the feature page SHALL NOT hard-code macOS traffic-light offsets, native close interception, or expanded-sidebar title hiding rules

#### Scenario: macOS policy remains public-shell safe
- **WHEN** Apple titlebar context rules are added or changed in the public repository
- **THEN** they MUST NOT include StoreKit, subscription, entitlement, receipt, price, product ID, paywall, private overlay, or `AccessDecision.source` business branching
