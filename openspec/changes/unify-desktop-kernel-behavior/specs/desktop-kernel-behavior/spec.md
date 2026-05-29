## ADDED Requirements

### Requirement: Desktop kernel policies SHALL own shared desktop behavior

The system SHALL express Windows/macOS shared desktop behavior through centralized desktop kernel policies rather than page-local platform branches or single-platform shell assumptions. Feature pages SHALL provide semantic intent; platform skins SHALL render that intent with platform-appropriate chrome.

#### Scenario: Feature provides semantic intent
- **WHEN** a desktop feature needs route motion, layout tier, secondary pane, modal surface, search presentation, compose presentation, preview behavior, or window command behavior
- **THEN** the feature SHALL ask a desktop kernel policy, presentation model, shell seam, or equivalent centralized decision point for that behavior
- **AND** the feature SHALL NOT directly branch on Windows versus macOS for shared desktop kernel semantics unless an explicit documented exception exists

#### Scenario: Platform skin renders policy output
- **WHEN** a desktop shell receives kernel policy output for Windows or macOS
- **THEN** the shell SHALL render the behavior using platform-appropriate chrome and controls
- **AND** the shell SHALL NOT reinterpret the same semantic intent through a separate page-local or platform-local rule that can drift from the kernel policy

#### Scenario: Unsupported platform behavior is explicit
- **WHEN** a platform shell cannot support a desktop kernel behavior such as resize, overlay pane, modal motion, native close mapping, or search presentation
- **THEN** the policy output SHALL expose an explicit unsupported or fallback capability
- **AND** the shell SHALL NOT silently ignore policy inputs while appearing to support them

### Requirement: Desktop route and layout policy SHALL be shared across Windows and macOS

The system SHALL define desktop route motion and layout tiers as shared desktop behavior. Windows/macOS may map shared tiers to different visual chrome, but breakpoint and navigation/surface capability decisions SHALL come from a shared desktop policy.

#### Scenario: Drawer destination route motion is resolved by desktop policy
- **WHEN** drawer destination navigation replaces the current route on a desktop platform
- **THEN** the route transition style and animation-enabled decision SHALL be resolved by a desktop route motion policy
- **AND** Windows and macOS SHALL NOT each hardcode independent route replacement animation rules in feature navigation helpers

#### Scenario: Desktop layout tier is shared
- **WHEN** a desktop shell or memo list resolves navigation mode, side pane support, secondary pane support, or default secondary pane visibility
- **THEN** it SHALL use a shared desktop layout policy with platform as an input
- **AND** it SHALL NOT rely on a Windows-only layout spec plus separate macOS magic breakpoints for the same semantic tier

#### Scenario: Platform chrome remains mapped below the layout policy
- **WHEN** the shared desktop layout policy returns a tier and navigation mode
- **THEN** Windows MAY render command bar, overlay navigation, rail, or expanded sidebar according to Windows chrome rules
- **AND** macOS MAY render toolbar, traffic-light safe area, rail, or expanded sidebar according to macOS chrome rules

### Requirement: Desktop window policy SHALL separate decisions from lifecycle side effects

The system SHALL separate pure desktop window command policy from lifecycle side effects. Window lifecycle side effects such as close-to-tray, full-exit cleanup, secondary route close dispatch, tray disposal, hotkey unregister, and database cleanup SHALL remain owned by application-level desktop coordinators or explicit composition-root callbacks.

#### Scenario: Main-window close command enters lifecycle coordinator
- **WHEN** a Flutter-drawn Windows or shared desktop main-window close control is activated
- **THEN** the command SHALL enter the shared desktop close coordinator or an injected equivalent callback
- **AND** it SHALL NOT directly call `windowManager.close()` in a way that bypasses close-to-tray, full-exit cleanup, or close request logging

#### Scenario: Window chrome decision is pure
- **WHEN** a shell decides whether to show minimize, maximize, close, frameless drag regions, minimum size constraints, or titlebar safe-area reservations
- **THEN** the reusable policy decision SHALL be testable without importing feature UI, Riverpod state, database models, sync services, or API code
- **AND** any required side effect SHALL be invoked through a shell callback, platform adapter, or application desktop coordinator

#### Scenario: Minimum-size policy is centralized
- **WHEN** a desktop window or subwindow uses frameless chrome or custom window controls
- **THEN** minimum and maximum size constraints SHALL be resolved from a desktop window policy or documented subwindow-specific exception
- **AND** the same main-window size contract SHALL NOT be duplicated independently in native runner code and Dart shell code without a policy link or verification

### Requirement: Desktop surface policy SHALL govern secondary panes and modal surfaces

The system SHALL route secondary pane and modal surface behavior through a desktop surface policy. The policy SHALL describe presentation kind, width bounds, resize capability, motion, barrier, blur, and fallback capability separately from the platform-specific renderer.

#### Scenario: Secondary pane capability is explicit
- **WHEN** a feature provides a desktop secondary pane such as preview, inspector, utility, or contextual detail
- **THEN** the desktop surface policy SHALL decide whether the pane is inline, overlay, hidden, resizable, or unsupported for the current platform and layout tier
- **AND** Windows/macOS shell renderers SHALL consume the same semantic capability contract

#### Scenario: Secondary pane motion is not silently discarded
- **WHEN** a secondary pane motion spec or resize callback is provided through a desktop shell seam
- **THEN** the platform shell SHALL either apply the motion/resize semantics or expose a documented unsupported capability
- **AND** tests or guardrails SHALL fail if a platform accepts policy inputs that are never used and no exception is documented

#### Scenario: Modal surface behavior is policy-owned
- **WHEN** a desktop feature presents an editor, utility, confirmation, or task surface as a modal
- **THEN** barrier color, blur, placement, motion, and dismissibility semantics SHALL come from desktop surface policy or an approved adaptive surface seam
- **AND** feature pages SHALL NOT create separate Windows/macOS modal behavior forks for the same semantic modal task

### Requirement: Desktop memo list presentation SHALL be semantic and platform-neutral

The home memo list SHALL express desktop presentation through semantic policy/model outputs instead of direct Windows/macOS booleans. The memo list may still render platform-specific titlebars and toolbar skins, but shared desktop behavior SHALL be decided by desktop kernel policy.

#### Scenario: Memo list layout state receives semantic desktop presentation
- **WHEN** memo list view state resolves header height, list padding, preview pane support, default click-to-preview, inline compose, and primary action visibility
- **THEN** it SHALL use a semantic desktop presentation model or equivalent policy output
- **AND** it SHALL NOT require callers to pass raw `isWindowsDesktop` and `isMacosDesktop` booleans to decide shared desktop behavior

#### Scenario: Desktop search presentation is policy-driven
- **WHEN** the user opens search from a desktop shortcut, titlebar action, or memo list command
- **THEN** desktop search presentation SHALL be selected through a desktop search policy or memo-list presentation model
- **AND** the shared search state machine SHALL NOT be split into Windows-only header search versus unrelated macOS/mobile search behavior without a documented policy reason

#### Scenario: Desktop compose presentation is policy-driven
- **WHEN** the user opens text compose or voice-result compose from the desktop memo list
- **THEN** desktop compose presentation SHALL be selected through a desktop compose policy or memo-list presentation model
- **AND** the route delegate SHALL NOT depend on a Windows-named compose presenter as the only desktop modal compose path

#### Scenario: Preview behavior follows desktop layout policy
- **WHEN** the desktop memo list determines whether a memo click opens or updates the preview pane
- **THEN** that behavior SHALL follow the shared desktop layout/presentation policy for Windows and macOS
- **AND** feature code SHALL NOT hide preview behavior behind platform-specific one-off checks

### Requirement: Desktop kernel behavior SHALL be protected by guardrails

The system SHALL include focused tests or architecture guardrails that prevent desktop kernel behavior from drifting back into feature pages, Windows-only helpers, macOS-only helpers, or direct window-manager calls.

#### Scenario: Feature platform branching is introduced
- **WHEN** a feature page adds a Windows/macOS branch for route motion, desktop layout tier, secondary pane behavior, modal surface behavior, search presentation, compose presentation, preview policy, or main-window close behavior
- **THEN** architecture guardrails SHALL fail unless the branch is documented as a platform skin exception rather than shared kernel behavior

#### Scenario: Direct main-window close is introduced
- **WHEN** a desktop shell or main-window control introduces a direct `windowManager.close()` call for user-initiated close
- **THEN** tests or guardrails SHALL fail unless the call is inside the approved lifecycle coordinator or a documented final termination step

#### Scenario: Policy implementation changes
- **WHEN** desktop route, layout, window, surface, search, compose, or preview policy changes
- **THEN** focused tests SHALL cover both Windows and macOS policy output or document an explicit unsupported platform fallback
