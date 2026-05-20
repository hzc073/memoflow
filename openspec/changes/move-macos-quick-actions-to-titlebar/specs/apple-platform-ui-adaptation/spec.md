## ADDED Requirements

### Requirement: macOS home titlebar SHALL use hybrid native window chrome
The Apple platform UI adaptation SHALL allow the macOS home window to place Flutter-owned toolbar content in the titlebar region while preserving native macOS window controls and window semantics.

#### Scenario: Quick action pills are shown in the macOS titlebar
- **WHEN** the app runs in the macOS main home window with header quick actions enabled
- **THEN** the three home quick action pills SHALL be rendered in the macOS titlebar content area or an equivalent hybrid toolbar region
- **AND** the implementation SHALL reuse the existing quick action state and `MemosListPillRow` or an equivalent shared Flutter composition
- **AND** the same pills SHALL NOT be duplicated in the normal content header at the same time

#### Scenario: Native traffic lights are preserved
- **WHEN** the macOS main window renders the hybrid titlebar
- **THEN** the native close, minimize, and zoom traffic-light controls SHALL remain visible and usable
- **AND** the Flutter titlebar content SHALL reserve enough left-side safe space to avoid overlapping those controls
- **AND** the implementation MUST NOT add Windows-style self-drawn close, minimize, or maximize buttons as the default macOS window controls

#### Scenario: Titlebar interactions remain separated
- **WHEN** the user interacts with titlebar quick action pills, search, sort, or other action controls
- **THEN** those controls SHALL receive pointer events normally
- **AND** draggable titlebar regions SHALL NOT intercept clicks intended for interactive controls
- **AND** empty titlebar background regions MAY remain draggable

#### Scenario: macOS window semantics are preserved
- **WHEN** the user closes, minimizes, zooms, enters fullscreen, uses `Cmd+W`, or invokes relevant Window menu commands
- **THEN** the macOS main window SHALL continue to follow native window semantics
- **AND** custom Flutter titlebar content SHALL NOT replace those system behaviors with Windows-specific command bar behavior

### Requirement: macOS titlebar adaptation SHALL preserve architecture boundaries
The macOS home titlebar adaptation SHALL keep native window chrome setup and feature-owned UI composition separated.

#### Scenario: Native window chrome setup is added
- **WHEN** macOS native titlebar or full-size-content window properties are added or changed
- **THEN** those changes SHALL be centralized in the macOS Runner or an approved platform/window chrome seam
- **AND** feature widgets SHALL NOT scatter native window setup logic through memo list screens

#### Scenario: Quick action titlebar UI is composed
- **WHEN** the titlebar renders home quick action pills
- **THEN** `features/memos` or an approved shell composition point SHALL own the Flutter quick action UI
- **AND** `core` or `application/desktop` MUST NOT add new imports from `features/memos` solely to construct the pill row

#### Scenario: Public Apple shell remains commercial-free
- **WHEN** macOS titlebar, home shell, quick action, Runner, or window chrome code is added or changed in the public repository
- **THEN** it MUST NOT include StoreKit, subscription, buyout, entitlement, receipt, product ID, price, paywall, App Store Connect, signing secret, notarization, TestFlight, or private release automation logic
