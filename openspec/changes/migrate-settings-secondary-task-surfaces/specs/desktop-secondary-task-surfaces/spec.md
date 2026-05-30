## MODIFIED Requirements

### Requirement: Desktop task-like secondary flows SHALL use a shared task surface

桌面端任务型二级流程 SHALL 通过共享桌面任务表面呈现，而不是在 feature 页面中直接手写完整页面 `Scaffold + AppBar`、平台窗口避让或 titlebar padding。任务型二级流程包括创建、编辑、配置、导入、重排、管理条目、确认提交等有明确完成/取消边界的短任务。

#### Scenario: Collection editor opens on desktop
- **WHEN** the user opens create or edit collection from the desktop collections screen
- **THEN** the flow SHALL be presented in a shared desktop task surface
- **AND** the surface SHALL provide a visible task title and explicit close or cancel affordance
- **AND** the surface SHALL NOT rely on a top-left full-page `AppBar` back button that can overlap native window controls

#### Scenario: Task surface is reused by a migrated task flow
- **WHEN** a migrated task-like secondary flow needs title, body, bottom actions, close behavior, or size limits on desktop
- **THEN** it SHALL consume the shared task surface seam
- **AND** it SHALL NOT duplicate macOS traffic-light width, Windows caption-control spacing, or page-local desktop chrome offsets

#### Scenario: Shortcut editor opens on desktop
- **WHEN** the user creates or edits a shortcut from a desktop settings page or desktop memo title menu
- **THEN** the shortcut editor SHALL be presented in a shared desktop task surface
- **AND** completion SHALL return the same `ShortcutEditorResult` as the previous route-based flow
- **AND** mobile and tablet layouts SHALL preserve the existing route-based editor behavior

#### Scenario: AI service wizard opens on desktop
- **WHEN** the user starts the add AI service flow from desktop AI settings
- **THEN** the AI service wizard SHALL be presented in a shared desktop task surface
- **AND** the wizard SHALL provide visible task title and close/cancel affordance
- **AND** the existing proxy settings entry MAY keep its current nested page behavior until a later change explicitly migrates it

### Requirement: Desktop task surfaces SHALL preserve task completion and cancellation semantics

桌面任务表面 SHALL 明确区分保存/完成、取消/关闭和系统窗口关闭。关闭任务表面 SHALL 返回到父页面或父任务，不得关闭整个主窗口；保存成功 SHALL 将结果传回调用方。

#### Scenario: User saves a task surface
- **WHEN** the user completes a desktop task surface such as creating a collection
- **THEN** the task SHALL perform the same validation and persistence as the previous route-based flow
- **AND** the task result SHALL be returned to the caller
- **AND** the parent view SHALL be able to refresh or continue from the result

#### Scenario: User closes a task surface with unsaved changes
- **WHEN** the user activates close, cancel, Escape, or an outside-dismiss affordance on a task surface with unsaved changes
- **THEN** the task SHALL apply the same save/discard/cancel confirmation policy as explicit route dismissal
- **AND** the task SHALL NOT silently discard edits
- **AND** the task SHALL NOT close the whole desktop window

#### Scenario: Migrated settings task returns to parent
- **WHEN** a desktop shortcut editor or AI service wizard task is cancelled or completed
- **THEN** the task SHALL close back to the invoking settings or memo surface
- **AND** it SHALL NOT close the whole desktop window or reset the parent navigation stack

### Requirement: Desktop task surface seams SHALL remain layer-safe

共享桌面任务表面 seam SHALL live in an approved platform/shared UI layer and SHALL remain independent of feature, state, application, data, API, and private/commercial code.

#### Scenario: Shared task surface seam is changed
- **WHEN** the shared task surface widget, presenter, helper, or route adapter is added or changed
- **THEN** it MUST NOT import `features/*`, `state/*`, `application/*`, `data/*`, or API code
- **AND** it MUST NOT include subscription, billing, entitlement, receipt, paywall, StoreKit, private overlay, or paid-feature branching logic

#### Scenario: Feature content is embedded in a task surface
- **WHEN** a feature page provides content for the shared task surface
- **THEN** the feature MAY provide semantic title, content, action widgets, callbacks, and result handling
- **AND** platform-specific task surface layout SHALL remain owned by the shared seam

#### Scenario: Migrated settings task entry points are guarded
- **WHEN** shortcut editor or AI service wizard entry points are migrated to desktop task surfaces
- **THEN** guardrail coverage SHALL prevent those production entry points from directly pushing page-local `Scaffold + AppBar` task pages again
- **AND** the guarded files SHALL use semantic presenter helpers rather than duplicating desktop platform checks
