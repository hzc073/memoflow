# desktop-home-utility-embedding Specification

## Purpose
TBD - created by archiving change embed-desktop-utility-pages-in-home. Update Purpose after archive.
## Requirements
### Requirement: Desktop home SHALL embed utility views in the primary content column

When sync queue or notifications are opened from the desktop homepage shell, the app SHALL render the selected utility view inside the homepage primary content column instead of navigating to a standalone secondary page.

#### Scenario: Desktop user opens sync queue from home
- **GIVEN** the user is on the desktop homepage shell
- **WHEN** the user opens the sync queue from a drawer quick action, titlebar-adjacent action, or sync-status retry entry
- **THEN** the homepage primary content column SHALL show sync queue content
- **AND** the memo inline compose and memo list content SHALL be replaced while the sync queue utility view is active
- **AND** the desktop window titlebar / chrome SHALL remain owned by the homepage shell
- **AND** the sync queue local title SHALL expose a back affordance that returns the primary content column to the memo list.

#### Scenario: Desktop user opens notifications from home
- **GIVEN** the user is on the desktop homepage shell
- **WHEN** the user opens notifications from the drawer quick action or titlebar action
- **THEN** the homepage primary content column SHALL show notifications content
- **AND** the memo inline compose and memo list content SHALL be replaced while the notifications utility view is active
- **AND** the desktop window titlebar / chrome SHALL remain owned by the homepage shell
- **AND** the notifications local title SHALL expose a back affordance that returns the primary content column to the memo list.

#### Scenario: Desktop user opens utility view from another drawer page
- **GIVEN** the user is on a desktop drawer page other than all memos, such as explore, stats, tags, resources, recycle bin, settings, or about
- **WHEN** the user opens sync queue or notifications from that page's drawer chrome
- **THEN** the app SHALL return to the desktop homepage shell
- **AND** the homepage primary content column SHALL show the requested utility view
- **AND** the app SHALL NOT open a standalone sync queue or notifications route for that desktop drawer action.

### Requirement: Embedded utility views SHALL clear drawer selection

Desktop homepage utility views SHALL NOT highlight a primary drawer destination while active.

#### Scenario: Sync queue utility view is active
- **WHEN** the desktop homepage primary content column shows the sync queue utility view
- **THEN** the drawer selected destination SHALL be empty
- **AND** the selected tag path SHALL be empty.

#### Scenario: Notifications utility view is active
- **WHEN** the desktop homepage primary content column shows the notifications utility view
- **THEN** the drawer selected destination SHALL be empty
- **AND** the selected tag path SHALL be empty.

### Requirement: Mobile and standalone routes SHALL keep existing behavior

Embedding sync queue and notifications in the homepage primary column SHALL be limited to desktop homepage contexts.

#### Scenario: Mobile user opens sync queue or notifications
- **WHEN** the user opens sync queue or notifications on a mobile or tablet bottom-navigation surface
- **THEN** the app SHALL preserve the existing standalone or embeddedBottomNav navigation behavior
- **AND** it SHALL NOT replace the memo list primary content column via the desktop utility view state.

#### Scenario: Standalone route is opened outside desktop home
- **WHEN** `SyncQueueScreen` or `NotificationsScreen` is opened outside the desktop homepage shell
- **THEN** the screen SHALL preserve its existing standalone title, navigation, actions, and body behavior.

### Requirement: Embedded utility content SHALL NOT own top-level titlebar chrome

Embedded sync queue and notifications content SHALL render business content and local actions only, while delegating desktop titlebar and window-control avoidance to the homepage shell.

#### Scenario: Utility content is embedded in desktop home
- **WHEN** sync queue or notifications content is rendered inside the homepage primary content column
- **THEN** it SHALL NOT render a standalone `PlatformPage`, `DesktopShellHost`, `Scaffold.appBar`, or route-level Back affordance as the top-level titlebar owner
- **AND** it SHALL NOT encode macOS traffic-light or caption-control padding locally.

### Requirement: Embedded utility back SHALL clear utility state

Desktop embedded sync queue and notifications back affordances SHALL be local content navigation, not window or route dismissal.

#### Scenario: User returns from sync queue utility view
- **GIVEN** the desktop homepage primary content column shows the sync queue utility view
- **WHEN** the user activates the local back affordance
- **THEN** the utility view state SHALL be cleared
- **AND** the primary content column SHALL show the memo list and inline compose area again.

#### Scenario: User returns from notifications utility view
- **GIVEN** the desktop homepage primary content column shows the notifications utility view
- **WHEN** the user activates the local back affordance
- **THEN** the utility view state SHALL be cleared
- **AND** the primary content column SHALL show the memo list and inline compose area again.

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

