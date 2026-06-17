## ADDED Requirements

### Requirement: iPhone night navigation surfaces remain dark and readable
The system SHALL keep iPhone night-mode navigation surfaces, labels, icons, and top scroll chrome visually readable against dark backgrounds.

#### Scenario: Bottom navigation is dark in night mode
- **WHEN** the app runs on iPhone with `ThemeData.brightness == Brightness.dark` and bottom navigation mode is active
- **THEN** the bottom navigation background resolves to a dark surface before any alpha is applied
- **AND** selected and unselected destination icons and labels meet the app's dark-surface readability expectations

#### Scenario: Memo list top chrome does not expose a light surface
- **WHEN** the app runs on iPhone in night mode and the user scrolls the memo list upward under the pinned top chrome
- **THEN** the status-bar and `SliverAppBar` area MUST NOT expose white or light-mode background
- **AND** the top chrome remains visually connected to the memo list dark background

### Requirement: iPhone top-level sidebar entry remains available in bottom navigation mode
The system SHALL provide a working top-level sidebar or equivalent navigation surface for iPhone bottom navigation destinations that expose the home drawer entry.

#### Scenario: Collections sidebar opens from embedded bottom navigation
- **GIVEN** the app runs on iPhone with bottom navigation mode active
- **AND** the user is viewing the Collections destination
- **WHEN** the user taps the sidebar/menu button
- **THEN** the top-level navigation surface opens
- **AND** the user can select drawer destinations and tags through the existing `AppDrawer` content or an equivalent shared navigation surface

#### Scenario: PlatformPage drawer entry does not depend on Material Scaffold
- **GIVEN** an iPhone top-level destination is rendered through `PlatformPage`
- **AND** the page provides a drawer or top-level navigation entry
- **WHEN** the user invokes the sidebar/menu action
- **THEN** the action MUST NOT require `Scaffold.maybeOf(context).openDrawer()` to succeed
- **AND** the page remains usable when its outer scaffold is `CupertinoPageScaffold`

### Requirement: iPhone navigation boundary remains public-shell safe
The iPhone night navigation fix SHALL preserve public shell and modularity boundaries.

#### Scenario: No commercial logic is introduced
- **WHEN** iPhone navigation, drawer, bottom navigation, memo-list top chrome, or Apple shell code is changed
- **THEN** the change MUST NOT include subscription, billing, entitlement, receipt, StoreKit, product ID, paywall, price, private overlay, or `AccessDecision.source` business branching

#### Scenario: Platform seam does not import features
- **WHEN** drawer or navigation behavior is added to files under `memos_flutter_app/lib/platform`
- **THEN** those files MUST NOT import `features/*`, `state/*`, `application/*`, or app data repositories
- **AND** feature-owned drawer content MUST be passed into the seam by the caller or shell composition point

#### Scenario: Coupled UI area is kept equal or better structured
- **WHEN** implementation touches `features/home`, `features/collections`, `features/memos`, or `platform/widgets`
- **THEN** the touched behavior MUST be routed through an existing or newly introduced seam instead of adding page-specific iPhone-only workarounds
- **AND** regression tests MUST cover the seam behavior that prevents the same class of bug
