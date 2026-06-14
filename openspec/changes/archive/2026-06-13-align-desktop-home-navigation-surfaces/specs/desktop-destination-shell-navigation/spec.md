## ADDED Requirements

### Requirement: Desktop home quick actions SHALL reuse drawer destination navigation

桌面首页顶部快捷入口打开已有 top-level drawer destination 时，系统 SHALL 复用与侧边栏相同的 destination navigation seam，而不是为同一 destination 创建独立 push-route 语义。

#### Scenario: Desktop quick AI summary matches drawer navigation
- **GIVEN** app 运行在 desktop homepage memo list
- **WHEN** 用户点击顶部快捷胶囊中的 `aiSummary`
- **THEN** the app SHALL navigate using the same desktop destination semantics as selecting `AppDrawerDestination.aiSummary` from the sidebar
- **AND** the resulting AI summary destination SHALL expose the same selected drawer state, titlebar ownership, and back behavior as sidebar navigation
- **AND** the action SHALL NOT use a separate `Navigator.push` path that makes the destination feel like a different interface.

#### Scenario: Desktop quick daily review matches drawer navigation
- **GIVEN** app 运行在 desktop homepage memo list
- **WHEN** 用户点击顶部快捷胶囊中的 `dailyReview`
- **THEN** the app SHALL navigate using the same desktop destination semantics as selecting `AppDrawerDestination.dailyReview` from the sidebar
- **AND** the resulting daily review destination SHALL expose the same selected drawer state, titlebar ownership, and back behavior as sidebar navigation.

#### Scenario: Desktop quick destinations preserve account availability rules
- **GIVEN** a quick action maps to a destination that requires an account, such as explore or notifications
- **WHEN** the current workspace is local-library-only
- **THEN** the app SHALL preserve the existing unavailable feedback
- **AND** it SHALL NOT bypass drawer destination availability checks through the quick action path.

### Requirement: Desktop workspace-internal navigation SHALL use consistent motion policy

桌面首页中属于同一 workspace 的 quick action 和 drawer destination transitions SHALL use one consistent motion policy for the same target type.

#### Scenario: Top quick and sidebar destination motion match
- **GIVEN** app 运行在 desktop homepage context
- **WHEN** 用户通过顶部快捷入口进入 `aiSummary` 或 `dailyReview`
- **AND** 用户通过侧边栏进入同一 destination
- **THEN** both entry paths SHALL use the same destination transition policy for the current desktop navigation mode
- **AND** neither path SHALL add an extra route-level animation on top of the shared destination transition.

#### Scenario: Primary-column utility swap avoids route-level animation
- **GIVEN** app 运行在 desktop homepage context
- **WHEN** 用户打开 stats、sync queue、notifications 或 draft box as a primary-column utility
- **THEN** the transition SHALL be a workspace-internal content swap
- **AND** it SHALL NOT use a standalone route transition to replace the whole window surface.
