# desktop-home-inline-compose-resize Specification

## Purpose
TBD - created by archiving change fix-desktop-inline-compose-resize. Update Purpose after archive.
## Requirements
### Requirement: Desktop home inline compose SHALL expose resize on supported desktop platforms
Supported desktop home memo list surfaces SHALL render a resizable inline compose panel whenever the home inline compose layout is active and the current platform is explicitly supported for this capability.

Linux desktop is not adapted in this batch and MUST remain disabled or fallback unless a later change explicitly enables and verifies it.

#### Scenario: Windows home inline compose can be resized
- **GIVEN** the app is running on Windows desktop
- **AND** the user is viewing the home `MemosListScreen` with inline compose active
- **WHEN** the page renders the inline compose panel
- **THEN** the panel SHALL expose active resize handles
- **AND** dragging a resize handle SHALL change the panel dimensions within configured min/max bounds

#### Scenario: Unsupported Linux desktop does not silently enable resize
- **GIVEN** the app is running on Linux desktop
- **WHEN** the home inline compose panel is rendered
- **THEN** resize handles SHALL NOT be enabled unless Linux support is explicitly added by a later change
- **AND** the inline compose panel SHALL remain usable through the non-resizable fallback layout

### Requirement: Desktop home memo entry paths SHALL share resize capability decisions
All desktop entry paths that build the primary home memo list SHALL use the same resize capability decision instead of relying on scattered route-specific flags.

#### Scenario: Initial home route and drawer memos route match
- **GIVEN** the app is running on Windows desktop
- **WHEN** the user reaches all memos from the initial home route
- **AND** the user reaches all memos through a drawer or replacement destination route
- **THEN** both routes SHALL render the same inline compose resize capability state
- **AND** neither route SHALL accidentally disable resize by omitting an entry-specific flag

#### Scenario: Desktop utility return route preserves resize
- **GIVEN** the app is running on Windows desktop
- **AND** a desktop utility view such as notifications or sync queue is opened from home
- **WHEN** the user returns to the memo list primary content
- **THEN** the home inline compose resize capability SHALL remain available if it was available on the original memo list route

### Requirement: Inline compose resize SHALL preserve compose and desktop pane behavior
Resizing the desktop home inline compose panel SHALL change only the panel layout geometry and SHALL preserve compose state, desktop preview state, and keyboard ownership semantics.

#### Scenario: Resize preserves compose draft state
- **GIVEN** the desktop home inline compose editor contains draft text or pending attachments
- **WHEN** the user drags a resize handle
- **THEN** the draft text and pending attachments SHALL remain available
- **AND** the resize action SHALL NOT submit, clear, or close the inline compose editor

#### Scenario: Resize preserves desktop preview pane state
- **GIVEN** the desktop home right-side preview pane is visible
- **AND** the inline compose panel is visible
- **WHEN** the user resizes the inline compose panel
- **THEN** the preview pane SHALL remain governed by the existing desktop preview state
- **AND** the resize action SHALL NOT open, close, or replace the preview pane by itself

#### Scenario: Resize preserves keyboard ownership
- **GIVEN** the desktop home inline compose editor is focused
- **WHEN** the user resizes the inline compose panel
- **THEN** existing inline compose keyboard ownership and publish shortcut behavior SHALL remain unchanged
- **AND** the resize action SHALL NOT introduce selected-memo Enter navigation while the editor owns keyboard input

### Requirement: Inline compose resize layout SHALL persist safely
When a supported desktop user resizes the home inline compose panel, the app SHALL persist the layout through the existing device preference owner and restore it within current viewport bounds.

#### Scenario: Resized layout is persisted
- **GIVEN** the app is running on a supported desktop platform
- **WHEN** the user completes a resize interaction on the home inline compose panel
- **THEN** the app SHALL persist the resulting width, editor height, and normalized position using the existing `homeInlineComposePanelLayout` preference

#### Scenario: Saved layout is clamped on smaller viewport
- **GIVEN** a saved home inline compose panel layout exists
- **AND** the desktop viewport becomes smaller than the viewport where the layout was saved
- **WHEN** the home memo list renders
- **THEN** the restored panel SHALL be clamped within current viewport bounds
- **AND** it SHALL remain at least the configured minimum usable size

### Requirement: Inline compose resize SHALL be guarded against route drift
The implementation SHALL include focused automated verification that protects both resize hit testing and entry-path capability consistency.

#### Scenario: Real drag changes panel geometry
- **WHEN** focused widget tests render the supported desktop home inline compose panel
- **AND** the test drags a visible resize handle
- **THEN** the observed panel geometry or persisted layout SHALL change
- **AND** the test SHALL fail if the handle is present but not hit-testable in the real route tree

#### Scenario: New desktop memos entry does not bypass capability seam
- **WHEN** a new desktop memos entry path is added or an existing entry path is changed
- **THEN** tests or guardrails SHALL verify that the entry uses the shared resize capability decision
- **AND** the entry SHALL NOT hardcode a conflicting resize flag without an explicit documented exception

### Requirement: Inline compose resize SHALL preserve architecture boundaries
The desktop home inline compose resize fix SHALL preserve existing dependency directions and MUST NOT introduce new lower-layer imports from feature UI.

#### Scenario: No lower-layer reverse dependency is introduced
- **WHEN** the resize fix is implemented
- **THEN** `state`, `application`, and `core` layers MUST NOT add new imports from `features/memos`
- **AND** resize capability decisions SHALL be owned by an existing route composition seam, a same-layer feature helper, or a feature-agnostic platform/layout seam

### Requirement: Inline compose resize SHALL account for dynamic compose chrome
桌面首页 resizable inline compose 面板 SHALL 将 pending attachment preview、linked memo chips、location 状态、toolbar 和其他 editor 外内容计入 panel chrome height。`homeInlineComposePanelLayout.editorHeight` MUST continue to represent only the editor viewport height, and dynamic chrome changes MUST NOT corrupt the persisted editor height.

#### Scenario: Adding an attachment grows the panel without overflow
- **GIVEN** the app is running on a supported desktop platform
- **AND** the home inline compose panel is using a persisted or restored `editorHeight`
- **WHEN** the user adds one or more pending attachments
- **THEN** the panel SHALL allocate enough height for the attachment preview and existing toolbar chrome
- **AND** the editor viewport SHALL keep the restored `editorHeight` within configured bounds
- **AND** the UI SHALL NOT render a Flutter bottom overflow

#### Scenario: Removing attachments updates chrome without changing saved editor height
- **GIVEN** the home inline compose panel contains pending attachments
- **AND** the user has a persisted `homeInlineComposePanelLayout.editorHeight`
- **WHEN** the pending attachments are removed
- **THEN** the panel chrome height SHALL update to the current compose content
- **AND** the persisted editor height SHALL remain the user's editor viewport height
- **AND** toolbar and send controls SHALL remain visible and hit-testable

#### Scenario: Dynamic chrome remains within viewport bounds
- **GIVEN** the home inline compose panel is near the bottom of the available desktop viewport
- **WHEN** attachment preview, linked memo chips, or location state adds editor-external chrome
- **THEN** the panel SHALL clamp or reposition within the available viewport bounds
- **AND** the compose draft text and pending attachments SHALL remain available
- **AND** the resize handles SHALL remain usable when supported

### Requirement: Inline compose resize layout metrics SHALL be guarded against tight-parent measurement drift
The implementation SHALL provide focused automated verification for the resizable inline compose metrics path so dynamic editor-external chrome cannot be hidden by tight parent constraints.

#### Scenario: Controlled editor height reports attachment chrome
- **WHEN** a widget test renders `MemosListInlineComposeCard` with `desktopEditorViewportHeight`
- **AND** the composer contains at least one pending attachment
- **THEN** the reported layout metrics SHALL include the attachment preview in chrome or desired total height
- **AND** the measured editor viewport height SHALL still match the requested desktop editor viewport height

#### Scenario: Desktop route test fails on overflow regression
- **WHEN** a focused desktop `MemosListScreen` test renders the supported resizable home inline compose panel with pending attachments
- **THEN** the test SHALL assert that no Flutter overflow exception is produced
- **AND** the panel height SHALL be at least the editor viewport height plus current compose chrome height

### Requirement: Desktop date-filtered home view SHALL preserve inline compose resize

桌面首页内由 heatmap date selection 激活的日期过滤 SHALL preserve the home inline compose resize capability and saved layout when the platform otherwise supports resize.

#### Scenario: Heatmap date filter preserves saved inline compose layout
- **GIVEN** app 运行在支持 home inline compose resize 的 desktop platform
- **AND** 用户已有 persisted `homeInlineComposePanelLayout`
- **AND** 用户位于 desktop homepage memo list
- **WHEN** 用户从 drawer heatmap 选择一个有 memo 的日期
- **THEN** the memo list SHALL apply the selected date filter in the current home workspace
- **AND** the inline compose panel SHALL continue to use the resizable home layout
- **AND** the restored panel width、editor height、and normalized position SHALL remain clamped within current viewport bounds.

#### Scenario: Clearing date filter preserves inline compose layout
- **GIVEN** a desktop heatmap date filter is active in the homepage memo list
- **AND** the inline compose panel is using a resizable layout
- **WHEN** 用户清除日期过滤或返回全部笔记
- **THEN** the memo list SHALL show all memos again
- **AND** the inline compose panel SHALL keep the same saved resize capability and current compose draft state.

### Requirement: Route-level day pages SHALL not weaken home resize semantics

系统 SHALL distinguish standalone day-filtered routes from desktop homepage date-filter state so that route-specific filtering does not accidentally disable resize in the home workspace.

#### Scenario: Standalone day route keeps route behavior
- **GIVEN** app opens `/memos/day` outside the desktop homepage heatmap callback path
- **WHEN** the day-filtered `MemosListScreen` renders
- **THEN** it MAY keep the existing standalone day route layout behavior
- **AND** it SHALL NOT be required to expose desktop home inline compose resize solely because a date filter exists.

#### Scenario: Home resize decision uses explicit context
- **WHEN** implementation decides whether desktop home inline compose resize is enabled
- **THEN** the decision SHALL account for whether the current surface is the desktop homepage primary workspace
- **AND** it SHALL NOT use `dayFilter != null` as the sole reason to disable resize for a desktop home-local date filter.

### Requirement: Date-filtered home view SHALL preserve compose state

Applying or clearing a desktop home-local date filter SHALL NOT clear, submit, or recreate the inline compose draft.

#### Scenario: Draft survives heatmap filtering
- **GIVEN** the desktop home inline compose editor contains draft text, pending attachments, linked memos, or selected visibility
- **WHEN** 用户点击 drawer heatmap 中有 memo 的日期
- **THEN** the draft state SHALL remain available after the date filter is applied
- **AND** no pending attachment, linked memo, selected template, location state, or visibility selection SHALL be silently lost.

#### Scenario: Draft survives clearing heatmap filter
- **GIVEN** a desktop home-local date filter is active
- **AND** the inline compose editor contains draft state
- **WHEN** 用户清除日期过滤并返回全部笔记
- **THEN** the draft state SHALL remain available
- **AND** clearing the filter SHALL NOT trigger memo submission or draft reset.

