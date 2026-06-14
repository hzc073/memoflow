## ADDED Requirements

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
