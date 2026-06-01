## ADDED Requirements

### Requirement: macOS Quit SHALL remain an explicit full-exit command when close-to-menu-bar is enabled
macOS application menu and menu-bar exit actions SHALL continue to represent explicit full application exit even when macOS close-to-menu-bar is enabled. Closing the main window SHALL NOT silently replace Quit semantics.

#### Scenario: Application menu Quit exits the app
- **GIVEN** macOS close-to-menu-bar 偏好为 enabled
- **WHEN** 用户选择 application menu 中的 Quit
- **THEN** 系统 SHALL execute full application exit
- **AND** SHALL NOT interpret Quit as a request to hide the main window

#### Scenario: Cmd+Q remains full exit
- **GIVEN** macOS close-to-menu-bar 偏好为 enabled
- **WHEN** 用户按下 `Cmd+Q`
- **THEN** 系统 SHALL execute the same full application exit path used by the application menu Quit command

#### Scenario: Menu-bar exit remains full exit
- **GIVEN** main window is currently hidden by macOS close-to-menu-bar behavior
- **WHEN** 用户选择菜单栏图标菜单中的退出命令
- **THEN** 系统 SHALL execute full application exit
- **AND** SHALL NOT treat the menu-bar exit command as a hide/show toggle
