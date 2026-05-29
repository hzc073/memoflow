## ADDED Requirements

### Requirement: Windows shell close controls SHALL request shared close coordination

Windows Flutter-drawn main-window close controls SHALL request the shared desktop close coordinator instead of directly closing the native window. This preserves close-to-tray, full-exit cleanup ordering, repeated-exit idempotency, and close request logging.

#### Scenario: Windows command bar close button is pressed
- **GIVEN** the app is running as the primary Windows desktop instance
- **WHEN** the user activates a Flutter-drawn close button in the Windows desktop command bar or equivalent shell chrome
- **THEN** the app SHALL call `DesktopExitCoordinator.requestClose(...)` or an injected equivalent shared close command
- **AND** the button handler SHALL NOT directly call `windowManager.close()`

#### Scenario: Close-to-tray remains honored
- **GIVEN** Windows close-to-tray is enabled
- **WHEN** the user activates the shell close control
- **THEN** the shared close coordinator SHALL resolve the close request to hide-to-tray when tray support is available
- **AND** the app SHALL NOT run the full-exit cleanup sequence for that close request

#### Scenario: Full exit remains bounded when close-to-tray is disabled
- **GIVEN** Windows close-to-tray is disabled
- **WHEN** the user activates the shell close control
- **THEN** the shared close coordinator SHALL enter the same bounded full-exit lifecycle used by native window close and tray exit
- **AND** cleanup steps SHALL remain ordered before final main-window termination

#### Scenario: Direct close regressions are guarded
- **WHEN** desktop shell source or tests are checked
- **THEN** verification SHALL fail if a user-facing Windows main-window close control bypasses the shared close coordinator with direct native close calls
- **AND** final termination calls inside the approved exit coordinator MAY remain allowed
