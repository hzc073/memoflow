# home-memo-engagement Specification

## Purpose
TBD - created by archiving change show-home-memo-engagement. Update Purpose after archive.
## Requirements
### Requirement: Home memo cards show engagement previews when enabled
The system SHALL render a home-card engagement preview with liker avatars and recent comment content when the engagement preference is enabled.

#### Scenario: Memo with existing likes shows liker avatars
- **WHEN** a memo appears on the home memo list and it already has one or more likes or comments
- **THEN** the card SHALL display concrete liker avatars for recent likers
- **AND** the preview SHALL cap visible avatars to a small fixed number
- **AND** the preview SHALL indicate when additional people liked the memo beyond the visible avatars

#### Scenario: Memo with existing comments shows recent comment content
- **WHEN** a memo appears on the home memo list and it already has comments
- **THEN** the card SHALL display the latest one to two comment entries
- **AND** the preview SHALL include comment text content instead of only a numeric comment count
- **AND** when more comments exist than are previewed, the card SHALL expose a "view all comments" affordance that opens the existing comment surface

#### Scenario: Memo without engagement shows compact zero-state
- **WHEN** a memo appears on the home memo list and it has no likes and no comments
- **THEN** the card SHALL still show a compact engagement affordance
- **AND** the affordance SHALL not expand into a full comment thread by default

### Requirement: Home memo cards allow engagement actions without opening detail first
The system SHALL let users like and comment from the home memo card engagement surface without requiring navigation to `MemoDetailScreen` first.

#### Scenario: Like action toggles from the card surface
- **WHEN** the user taps the like control on a home memo card engagement surface
- **THEN** the system SHALL toggle the memo like state for the current user
- **AND** the visible likes count or state SHALL update to reflect the action

#### Scenario: Comment action opens a comment composer
- **WHEN** the user taps the comment control on a home memo card engagement surface
- **THEN** the system SHALL open a comment composer or shared engagement surface for that memo
- **AND** the user SHALL be able to submit a comment without first opening `MemoDetailScreen`

#### Scenario: View all comments opens the existing surface
- **WHEN** the user taps the home card affordance for viewing all comments
- **THEN** the system SHALL open the existing comment surface for that memo
- **AND** the detail page behavior and the existing comment bottom-sheet experience SHALL remain unchanged

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

### Requirement: Home engagement refreshes from Memos live events
The system SHALL refresh visible home memo engagement state from Memos `0.27.1+` `/api/v1/sse` live refresh events when the active server supports SSE and the engagement preference is enabled.

#### Scenario: Reaction upsert refreshes visible home engagement
- **WHEN** the app receives a `reaction.upserted` SSE event whose `name` identifies a memo currently visible on the home memo list
- **THEN** the system SHALL refresh that memo's reaction engagement state from the server
- **AND** the home memo card SHALL update the visible like state, like count, liker avatars, and other reaction summaries from the refreshed data

#### Scenario: Reaction delete refreshes visible home engagement
- **WHEN** the app receives a `reaction.deleted` SSE event whose `name` identifies a memo currently visible on the home memo list
- **THEN** the system SHALL refresh that memo's reaction engagement state from the server
- **AND** the home memo card SHALL update the visible like state, like count, liker avatars, and other reaction summaries from the refreshed data

#### Scenario: Comment creation refreshes visible home engagement
- **WHEN** the app receives a `memo.comment.created` SSE event whose `name` identifies a memo currently visible on the home memo list
- **THEN** the system SHALL refresh that memo's comment engagement state from the server
- **AND** the home memo card SHALL update the visible comment count and recent comment preview from the refreshed data

#### Scenario: Engagement preference disabled suppresses home live engagement rendering
- **WHEN** the engagement preference is disabled
- **AND** the app receives a reaction or comment SSE event for a memo on the home memo list
- **THEN** the home memo card SHALL continue to hide engagement UI
- **AND** the hidden UI SHALL NOT become visible solely because a live event was received

### Requirement: Live engagement refresh degrades safely when SSE is unavailable
The system SHALL treat Memos live refresh as an optional capability and preserve existing engagement behavior when `/api/v1/sse` is unavailable, unsupported, disconnected, or unauthenticated.

#### Scenario: Older server does not support SSE
- **WHEN** the active server version is older than Memos `0.27.1` or the SSE endpoint is unavailable
- **THEN** the system SHALL NOT require a live SSE connection for home memo cards to render
- **AND** existing engagement loading, manual refresh, navigation reload, and local optimistic like/comment behavior SHALL remain available

#### Scenario: SSE reconnect compensates for missed engagement events
- **WHEN** an SSE connection disconnects and later reconnects successfully
- **THEN** the system SHALL refresh active or visible engagement state that may have missed reaction or comment events
- **AND** the refreshed state SHALL come from the server rather than from cached SSE event payloads

#### Scenario: SSE payload is an invalidation hint
- **WHEN** the app receives a well-formed reaction or comment SSE event
- **THEN** the system SHALL treat the event as an invalidation hint for the affected memo
- **AND** the system SHALL NOT derive final like counts, comment previews, or creator lists solely from the SSE event payload

### Requirement: Live engagement refresh preserves architecture boundaries
The system SHALL implement live engagement refresh through stable data/state seams without adding reverse dependencies or moving shared SSE logic into memo widgets.

#### Scenario: SSE parsing stays outside memo widgets
- **WHEN** the app parses `/api/v1/sse` stream data, heartbeat comments, or live refresh event JSON
- **THEN** that parsing SHALL live in the Memos API/data layer or an equivalent non-widget service seam
- **AND** `MemoEngagementSurface`, home memo card widgets, and `MemoDetailScreen` SHALL NOT own SSE stream parsing or reconnection policy

#### Scenario: Engagement invalidation stays in provider or state owner
- **WHEN** a live refresh event needs to refresh reactions or comments for a memo
- **THEN** the mapping from live event type to engagement refresh SHALL live in a provider, controller, coordinator, or state-layer owner
- **AND** the implementation SHALL NOT introduce new imports from `state`, `application`, or `core` into `features/memos/**`

#### Scenario: No new lower-layer dependency on memo feature UI
- **WHEN** live engagement refresh is implemented during `evolve_modularity`
- **THEN** the change MUST NOT add new `state -> features`, `application -> features`, or `core -> state|application|features` imports
- **AND** reusable live refresh logic SHALL NOT be hidden inside screen or widget files

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

