## ADDED Requirements

### Requirement: Desktop home SHALL embed stats as a utility view

桌面首页上下文打开统计视图时，系统 SHALL 将统计内容渲染在 homepage primary content column 中，而不是打开独立统计 route。

#### Scenario: Desktop quick stats opens in primary content
- **GIVEN** app 运行在 Windows、macOS 或 Linux desktop
- **AND** 用户位于 desktop homepage memo list
- **WHEN** 用户点击顶部快捷胶囊中的 `monthlyStats`
- **THEN** homepage primary content column SHALL show stats content
- **AND** memo list、inline compose 和 desktop preview pane SHALL be replaced while stats utility is active
- **AND** desktop window titlebar / chrome SHALL remain owned by the homepage shell
- **AND** stats content SHALL expose a local affordance that returns the primary content column to the memo list.

#### Scenario: Stats utility does not create a standalone route
- **GIVEN** app 运行在 desktop homepage context
- **WHEN** 用户从顶部快捷入口打开统计
- **THEN** the app SHALL NOT push a standalone `StatsScreen` route for that action
- **AND** returning from stats SHALL clear desktop utility state instead of rebuilding the entire home route.

### Requirement: Desktop home utility selection SHALL cover stats consistently

桌面首页 utility selection SHALL treat stats the same class of primary-column utility content as sync queue、notifications 和 draft box, while preserving each utility's own local actions.

#### Scenario: Stats utility clears primary drawer selection
- **GIVEN** the desktop homepage primary content column shows the stats utility view
- **THEN** the drawer selected destination SHALL be empty or neutral
- **AND** selected tag path SHALL be empty
- **AND** returning from stats SHALL restore the memo destination selection when the memo list is shown again.

#### Scenario: Mobile stats route remains standalone
- **GIVEN** app 运行在 phone、tablet bottom navigation、或非 desktop home context
- **WHEN** 用户打开统计
- **THEN** the app SHALL preserve the existing standalone stats navigation behavior
- **AND** it SHALL NOT use desktop home utility state.

### Requirement: Desktop drawer heatmap date selection SHALL stay in the home workspace

桌面首页侧边栏热力图点击日期时，系统 SHALL 在当前 homepage memo workspace 内应用日期过滤，而不是通过 named route 新建一个 day page。

#### Scenario: Desktop heatmap day applies local date filter
- **GIVEN** app 运行在 desktop homepage memo list
- **AND** drawer heatmap 中某个日期有 memo
- **WHEN** 用户点击该日期
- **THEN** the current `MemosListScreen` SHALL apply that day as an effective date filter
- **AND** the app SHALL close the drawer or overlay if needed
- **AND** the app SHALL NOT push `/memos/day` for that desktop home action.

#### Scenario: Desktop destination heatmap day opens the same local date-filtered home view
- **GIVEN** app 运行在 desktop top-level destination，例如 AI summary、daily review、collections、resources、explore、tags、settings、notifications、about、recycle bin 或 draft box
- **AND** drawer heatmap 中某个日期有 memo
- **WHEN** 用户点击该日期
- **THEN** the app SHALL navigate to the memo home workspace with that day applied as a desktop home-local effective date filter
- **AND** the resulting memo list SHALL preserve the same inline compose resize capability and light motion behavior as selecting a heatmap day from the all-memos desktop home view
- **AND** the action SHALL NOT fall back to the standalone `/memos/day` route on supported desktop home surfaces.

#### Scenario: Empty heatmap day remains non-navigating
- **GIVEN** drawer heatmap 中某个日期没有 memo
- **WHEN** 用户点击该日期
- **THEN** the app SHALL show the existing no-memos feedback
- **AND** it SHALL NOT change the current memo list route, utility state, or date filter.

#### Scenario: Non-desktop heatmap date route is preserved
- **GIVEN** app 不在 desktop homepage memo list context
- **WHEN** 用户点击 heatmap 中有 memo 的日期
- **THEN** the app MAY preserve the existing `/memos/day` navigation behavior
- **AND** it SHALL remain functionally equivalent to the existing day-filtered memo route.
