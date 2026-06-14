## ADDED Requirements

### Requirement: Apple mobile PlatformPage SHALL preserve top-level drawer semantics
`PlatformPage` or its caller-provided Apple mobile equivalent SHALL provide a working top-level navigation surface when a page supplies drawer content on iPhone or iPadOS.

#### Scenario: iPhone PlatformPage drawer can be opened
- **WHEN** a top-level page renders through `PlatformPage` on iPhone and supplies `drawer`
- **THEN** the user can open the provided drawer content through the page's leading navigation action or an equivalent platform navigation surface
- **AND** the behavior MUST NOT silently no-op because the page is backed by `CupertinoPageScaffold`

#### Scenario: Drawer content remains caller owned
- **WHEN** Apple mobile drawer behavior is implemented in `PlatformPage` or an equivalent platform seam
- **THEN** the platform layer MUST NOT import `AppDrawer` or any `features/*` page
- **AND** the feature or home shell MUST remain responsible for composing the drawer content

#### Scenario: No drawer remains valid
- **WHEN** a `PlatformPage` on iPhone or iPadOS does not provide `drawer`
- **THEN** the page continues to render existing Cupertino chrome normally
- **AND** no drawer gesture, drawer button, or placeholder navigation surface is required

### Requirement: Apple mobile drawer adaptation SHALL preserve embedded home navigation
Apple mobile drawer adaptation SHALL integrate with `HomeEmbeddedNavigationHost` so bottom navigation destinations can reuse configured top-level navigation behavior.

#### Scenario: Embedded destination delegates drawer selection through host
- **GIVEN** a bottom navigation destination is rendered with `HomeEmbeddedNavigationHost`
- **WHEN** the user selects a destination or tag from the Apple mobile drawer surface
- **THEN** navigation delegates through `HomeEmbeddedNavigationHost`
- **AND** bottom navigation shell state remains active instead of pushing an unrelated standalone home stack

#### Scenario: Standalone destination keeps existing navigation behavior
- **GIVEN** the same destination is rendered outside bottom navigation mode
- **WHEN** the user opens the drawer or selects a drawer entry
- **THEN** existing Material, desktop, and non-embedded navigation behavior is preserved

### Requirement: Apple mobile dark surface adaptation SHALL include top scroll chrome
Apple platform UI adaptation SHALL treat iPhone dark-mode top scroll chrome as part of page-level platform surface behavior.

#### Scenario: Pinned app chrome has a stable dark backing
- **WHEN** an iPhone page uses pinned app chrome, `SliverAppBar`, or equivalent top navigation over scrollable content in dark mode
- **THEN** the chrome MUST have a stable dark backing surface
- **AND** scroll movement MUST NOT reveal light-mode page background under the status bar or top toolbar

#### Scenario: Surface fix avoids feature-page duplication
- **WHEN** multiple Apple mobile top-level pages need the same dark top-surface behavior
- **THEN** the behavior SHOULD be handled by a shared platform/page/shell seam where practical
- **AND** feature pages MUST NOT create duplicate iPhone-only page trees for the same dark-mode surface rule
