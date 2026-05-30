## ADDED Requirements

### Requirement: Desktop task surfaces SHALL not be treated as pushed titlebar routes

桌面任务表面 SHALL have its own task chrome and SHALL NOT be treated as a pushed main-window titlebar route. Its title and dismissal controls belong to the task surface, not to the main window titlebar.

#### Scenario: Task surface is opened from a desktop destination
- **WHEN** a task-like secondary surface is opened from a desktop top-level destination
- **THEN** the main window titlebar navigation context SHALL remain owned by the parent destination
- **AND** the task surface SHALL render its own title and close/cancel affordance inside the task surface
- **AND** the task surface SHALL NOT add a main-window titlebar back button

#### Scenario: Native window close is activated while task surface is open
- **WHEN** the user activates native desktop window close while a task surface is open
- **THEN** the window close policy SHALL remain the app's normal window close policy
- **AND** the task surface close/cancel affordance SHALL remain the way to dismiss only the task
- **AND** unsaved task protection SHALL still be honored when the task surface itself is dismissed
