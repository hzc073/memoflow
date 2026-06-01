## ADDED Requirements

### Requirement: macOS close-to-menu-bar SHALL use the application desktop lifecycle seam
macOS 主窗口 close-to-menu-bar 决策与窗口隐藏副作用 SHALL 由 `DesktopExitCoordinator`、`DesktopTrayController` 或等价 application-owned desktop lifecycle seam 承载。Feature pages、settings rows、desktop shell widgets 和 native menu command glue SHALL NOT 直接执行会绕过 close policy 的主窗口 close/hide/exit 副作用。

#### Scenario: Native close enters coordinator
- **WHEN** macOS native main-window close request 到达 Flutter desktop lifecycle layer
- **THEN** request SHALL enter shared desktop close coordinator 或等价 injected close callback
- **AND** coordinator SHALL decide between secondary-route close、hide-to-menu-bar、native/full exit path

#### Scenario: Settings UI only changes preference state
- **WHEN** 用户切换 macOS close-to-menu-bar 设置
- **THEN** settings UI SHALL only update device preference state through the settings owner/provider seam
- **AND** settings UI SHALL NOT directly call `windowManager.hide()`、`windowManager.close()`、`NSApplication.terminate` 或 tray/menu-bar APIs

#### Scenario: Close policy remains testable without UI imports
- **WHEN** macOS close request policy is evaluated in tests
- **THEN** policy SHALL be testable from application/core-owned decision inputs such as platform、preference、tray support 和 secondary-route state
- **AND** testable policy code SHALL NOT import `features/*` widgets or settings screens

#### Scenario: Direct close bypass is guarded
- **WHEN** desktop shell source、macOS Runner glue 或 tests are checked
- **THEN** verification SHALL fail or require an explicit documented exception if a user-facing macOS main-window close path bypasses the approved lifecycle coordinator
