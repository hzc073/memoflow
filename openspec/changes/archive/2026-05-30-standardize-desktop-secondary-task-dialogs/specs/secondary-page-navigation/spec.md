## ADDED Requirements

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
