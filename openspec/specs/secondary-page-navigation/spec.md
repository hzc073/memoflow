# secondary-page-navigation Specification

## Purpose
TBD - created by archiving change fix-desktop-settings-nested-navigation. Update Purpose after archive.
## Requirements
### Requirement: Full-page secondary pages SHALL use explicit back navigation

所有 full-page 二级页面 SHALL 显示明确的 App 内返回语义，而不是依赖系统窗口关闭按钮、页面右上角 `X`、或隐式关闭行为来返回上一级。

本规则适用于软件内所有完整页面级二级页面，包括但不限于设置二级页、功能详情页、分享相关页面、编辑/确认类完整页面。短暂浮层如 `AlertDialog`、popover、tooltip、bottom sheet 不属于本 requirement 的 full-page 二级页面。

#### Scenario: Desktop secondary page chrome is rendered
- **WHEN** a full-page secondary page is displayed on desktop
- **THEN** it SHALL render an App-level back affordance plus the secondary page title
- **AND** the title format SHOULD be equivalent to `Back + Page Title`
- **AND** the back affordance SHALL return to the parent page or parent task level
- **AND** it SHALL NOT close the whole desktop window unless the page is itself the root of a dedicated one-shot task.

#### Scenario: Mobile or tablet secondary page chrome is rendered
- **WHEN** a full-page secondary page is displayed on phone or tablet
- **THEN** it SHALL keep a platform-appropriate back affordance and title
- **AND** the back affordance SHALL return to the parent page or parent task level
- **AND** it SHALL respect platform safe areas and navigation bars.

#### Scenario: Secondary page contains unsaved or pending work
- **WHEN** a user activates the App-level back affordance on a secondary page with unsaved edits, pending uploads, pending share processing, or destructive cancellation risk
- **THEN** the page MAY ask for confirmation before returning
- **AND** the confirmation SHALL make the consequence clear
- **AND** the back affordance SHALL NOT silently close the whole app window.

### Requirement: Desktop secondary page chrome SHALL avoid native window controls

桌面端 full-page 二级页面的标题、返回按钮、toolbar、拖拽区域和内容起点 SHALL 避开系统窗口控制区域。页面 chrome 不得与 macOS traffic lights 或 Windows/Linux titlebar controls 重叠。

#### Scenario: macOS secondary page is displayed
- **WHEN** a full-page secondary page is displayed in a macOS desktop window
- **THEN** App-rendered title and back controls SHALL NOT overlap the traffic lights area
- **AND** the page SHALL NOT render an App-owned top-right `X` close button as page navigation
- **AND** the native red close button SHALL remain a window close control, not a route back control.

#### Scenario: Windows or Linux secondary page is displayed
- **WHEN** a full-page secondary page is displayed in a Windows or Linux desktop window
- **THEN** App-rendered title and back controls SHALL NOT overlap native window controls
- **AND** desktop page navigation SHALL still be expressed through App-level back affordance, not through native window close.

#### Scenario: Secondary page is opened from a desktop sidebar or settings window
- **WHEN** the parent surface uses a sidebar, split layout, rail, or settings window shell
- **THEN** secondary page chrome SHALL remain inside a safe App content or toolbar region
- **AND** the secondary title SHALL NOT be positioned inside native titlebar control hit areas.

### Requirement: Native desktop close SHALL close the window and reset root page on reopen

系统原生桌面窗口关闭按钮 SHALL keep native close semantics. It SHALL close the current desktop window rather than pop nested App routes. When a root-scoped desktop surface is reopened, it SHALL start from its root page instead of restoring a stale secondary page.

#### Scenario: macOS red close button is used on a secondary page
- **WHEN** the user clicks the macOS red close button while a secondary page is active
- **THEN** the desktop window SHALL close
- **AND** the app SHALL NOT treat that click as a request to navigate back inside the secondary page stack
- **AND** reopening the same root-scoped surface SHOULD show the root page.

#### Scenario: Settings window is reopened after native close
- **WHEN** the desktop settings window is closed from any nested settings page
- **AND** the user opens settings again
- **THEN** the settings window SHALL display the settings home page
- **AND** it SHALL NOT restore the previously active secondary settings page by default.

#### Scenario: One-shot task window is reopened after native close
- **WHEN** a dedicated one-shot task window such as a share flow is closed natively
- **THEN** reopening that feature SHALL start from the task's valid entry state
- **AND** it SHALL NOT restore an invalid or stale secondary route unless the task explicitly supports draft/session recovery.

### Requirement: Share-related full-page flows SHALL follow secondary page navigation rules

分享相关 full-page flows SHALL follow the same secondary page navigation and desktop chrome rules as settings and other feature pages.

#### Scenario: Share flow opens a full-page secondary page
- **WHEN** a system share entry, third-party share capture, share preview, or share edit/confirm flow displays a full-page route
- **THEN** it SHALL render platform-appropriate `Back + Page Title` navigation when it is not the root task surface
- **AND** its title/back area SHALL avoid native window controls on desktop
- **AND** macOS SHALL NOT show an App-owned top-right `X` for that full-page route.

#### Scenario: Share flow needs explicit cancellation
- **WHEN** a share-related secondary page must allow canceling the whole share task
- **THEN** the cancellation action SHALL be explicit, such as a labeled `Cancel` or task-specific action
- **AND** it SHALL NOT be represented as a generic desktop-window-style `X` on macOS.

### Requirement: Navigation implementation SHALL be centralized through approved seams

二级页面返回、标题、窗口控制避让、以及桌面 root reset behavior SHALL be implemented through shared navigation/page/chrome seams where a shared seam exists, rather than ad hoc per-screen layout fixes.

#### Scenario: A new full-page secondary route is added
- **WHEN** a new full-page secondary page is introduced
- **THEN** it SHOULD use the approved shared page/navigation chrome seam
- **AND** it SHOULD NOT hand-roll titlebar offsets, macOS traffic-light padding, or close-vs-back behavior locally.

#### Scenario: Existing secondary pages are migrated
- **WHEN** existing settings, share, or feature secondary pages are migrated
- **THEN** they SHOULD converge on the same shared back/title semantics
- **AND** touched pages SHALL leave navigation/chrome behavior equal or better structured than before.

### Requirement: Task-like secondary surfaces SHALL be classified separately from full-page secondary pages

系统 SHALL distinguish full-page secondary pages from task-like secondary surfaces. Full-page secondary pages continue to use App-level back navigation and safe page chrome; task-like secondary surfaces MAY use dialog, panel, or equivalent task presentation with explicit close/cancel semantics instead of a full-page back AppBar.

#### Scenario: Task-like flow is opened on desktop
- **WHEN** a desktop flow represents create, edit, configure, import, reorder, or manage-items work with a clear completion boundary
- **THEN** it MAY be presented as a task-like secondary surface
- **AND** it SHALL provide explicit close/cancel and completion actions
- **AND** it SHALL NOT be required to render a full-page `Back + Page Title` AppBar

#### Scenario: Reading or detail flow is opened on desktop
- **WHEN** a desktop flow represents reading, browsing, previewing, or long-form detail navigation
- **THEN** it SHALL remain eligible for full-page secondary navigation
- **AND** it SHALL keep App-level back navigation when it is implemented as a full-page secondary page
- **AND** it SHALL NOT be forced into a centered task dialog solely for visual consistency

#### Scenario: Existing full-page secondary page is converted to task surface
- **WHEN** an existing full-page secondary route is migrated to a task-like secondary surface
- **THEN** the migration SHALL preserve parent return behavior, unsaved-change protection, and task result delivery
- **AND** the implementation SHALL document the classification reason in the change tasks or inventory

