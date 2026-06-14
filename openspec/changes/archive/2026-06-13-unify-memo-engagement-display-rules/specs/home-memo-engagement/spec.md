## MODIFIED Requirements

### Requirement: Home engagement follows the same preference gate as detail engagement
The system SHALL use a single memo engagement preference gate to determine whether any supported memo surface displays likes and comments.

#### Scenario: Preference disabled hides all supported memo engagement surfaces
- **WHEN** the memo engagement preference is disabled in a server-backed workspace
- **THEN** home memo cards SHALL not show the engagement summary or action surface
- **AND** desktop preview pane SHALL not show likes, liker avatars, comment previews, comment lists, or comment actions
- **AND** memo detail surfaces SHALL not show likes, comments, or engagement actions
- **AND** desktop reader, explore detail, notification detail, or equivalent read-only memo detail entries SHALL NOT bypass the preference to show memo engagement.

#### Scenario: Preference enabled shows engagement on supported remote surfaces
- **WHEN** the memo engagement preference is enabled in a server-backed workspace
- **THEN** home memo cards MAY show the engagement preview
- **AND** desktop preview pane MAY show memo engagement when its supplementary sections are visible
- **AND** memo detail surfaces MAY show memo engagement when their supplementary sections are visible
- **AND** each surface SHALL still respect its own layout constraints and existing support for compact or detail engagement presentation.

#### Scenario: Surface support does not bypass the preference
- **WHEN** a memo surface supports rendering likes and comments
- **THEN** that surface MAY declare that support through a semantic flag, parameter, or local layout policy
- **AND** the final display decision SHALL still use the unified effective memo engagement gate
- **AND** the implementation SHALL NOT use `showEngagement: true`、`shouldShowEngagement: true`、`widget.showEngagement || preference` 或 equivalent force-display logic to bypass the user preference.

## ADDED Requirements

### Requirement: Local library mode SHALL NOT support memo engagement display
The system SHALL treat memo likes and comments as unsupported in local library mode.

#### Scenario: Local library home cards hide engagement
- **GIVEN** the active workspace is a local library
- **WHEN** a memo appears on the home memo list
- **THEN** the card SHALL NOT show like buttons, comment buttons, counts, liker avatars, comment previews, or compact engagement zero-state
- **AND** the card SHALL NOT mount `MemoEngagementSurface`.

#### Scenario: Local library preview and detail hide engagement
- **GIVEN** the active workspace is a local library
- **WHEN** the user opens a memo in desktop preview pane, memo detail, desktop reader surface, explore detail, notification detail, or equivalent memo reading surface
- **THEN** the surface SHALL NOT show likes, comments, liker avatars, comment composer, comment list, or engagement actions
- **AND** it SHALL NOT mount `MemoEngagementSurface`
- **AND** it SHALL NOT trigger reactions/comments loading through `memoEngagementControllerProvider` or `memosApiProvider`.

#### Scenario: Local library setting does not imply support
- **GIVEN** the active workspace is a local library
- **WHEN** the user views preference settings
- **THEN** the memo engagement display setting SHALL be hidden or disabled
- **AND** if disabled instead of hidden, the setting SHALL communicate that local workspaces do not support likes and comments
- **AND** changing local workspace settings SHALL NOT make memo engagement visible in local library mode.

### Requirement: Memo engagement preference naming SHALL describe the unified control
The memo engagement preference SHALL use user-facing copy and runtime naming that describe a unified likes/comments display control rather than a surface-specific detail/home-card control.

#### Scenario: Setting label is surface-agnostic
- **WHEN** the preference setting is shown in a server-backed workspace
- **THEN** the user-facing label SHALL describe showing likes and comments generally, such as `显示点赞与评论` in Simplified Chinese and `Show likes and comments` in English
- **AND** the label SHALL NOT limit the control to home cards, memo details, or any other subset of surfaces.

#### Scenario: Runtime naming distinguishes preference from effective capability
- **WHEN** implementation updates memo engagement display code
- **THEN** new runtime naming SHOULD prefer `showMemoEngagement` for the stored/user preference
- **AND** it SHOULD prefer `effectiveShowMemoEngagement`、`canShowMemoEngagement` 或 equivalent naming for the resolved runtime gate
- **AND** widget parameters SHOULD avoid names that imply force-display behavior.

#### Scenario: Stored preferences remain compatible
- **WHEN** existing stored preferences contain the legacy `showEngagementInAllMemoDetails` key
- **THEN** the system SHALL preserve the user's existing preference value during migration or compatibility reads
- **AND** introducing a new storage key SHALL include migration or fallback behavior that prevents silent preference loss.

### Requirement: Memo engagement display gate SHALL preserve architecture boundaries
The system SHALL centralize memo engagement display decisions through a focused UI/provider seam and SHALL NOT move UI display policy into lower layers or API adapters.

#### Scenario: Display gate stays out of API compatibility code
- **WHEN** memo engagement display rules are implemented
- **THEN** implementation SHALL NOT modify Memos server API request/response models, route adapters, version compatibility logic, or `memos_flutter_app/lib/data/api`
- **AND** reactions/comments API behavior SHALL remain owned by existing data/state seams.

#### Scenario: Widgets consume a resolved gate instead of owning remote capability checks
- **WHEN** memo engagement surfaces render
- **THEN** widgets SHALL consume a resolved effective gate or an equivalent feature-local display decision
- **AND** repeated account/local-library/preference checks SHOULD NOT be duplicated across every screen
- **AND** `MemoEngagementSurface` SHALL only be mounted after the effective gate allows display.

#### Scenario: Forced display guardrail prevents regressions
- **WHEN** memo engagement display code is changed during `evolve_modularity`
- **THEN** focused tests or guardrails SHALL verify that no entry point can force likes/comments visible while the unified gate is false
- **AND** implementation SHALL NOT introduce new `state -> features`、`application -> features`、or `core -> state|application|features` dependencies
- **AND** public runtime files SHALL NOT add subscription、billing、entitlement、receipt、paywall、StoreKit、private overlay 或 paid-feature branching logic.
