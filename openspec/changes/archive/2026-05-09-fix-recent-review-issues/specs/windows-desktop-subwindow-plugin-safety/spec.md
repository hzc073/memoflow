## ADDED Requirements

### Requirement: Windows sub-windows avoid unavailable plugin surfaces
The system SHALL prevent Windows desktop sub-windows from presenting or invoking feature UI that requires plugins intentionally excluded from sub-window Flutter engine registration.

#### Scenario: Quick input does not initialize WebView location picker in a sub-window
- **GIVEN** the Windows quick-input compose surface is running in a desktop sub-window
- **AND** WebView plugins are not registered for that sub-window engine
- **WHEN** the user interacts with the quick-input toolbar
- **THEN** the system SHALL NOT initialize `WindowsEmbeddedMapHost` or `WebviewController` from that sub-window
- **AND** the location action SHALL be hidden, disabled, or routed to a WebView-capable main-window surface

#### Scenario: Main window location picker remains available
- **GIVEN** the Windows main app window has normal plugin registration
- **WHEN** the user opens the location picker from a main-window compose surface
- **THEN** the system SHALL preserve the existing Windows embedded map behavior

### Requirement: Sub-window plugin guardrails preserve architecture boundaries
The system SHALL protect Windows sub-window plugin safety without introducing new reverse dependencies across architecture layers.

#### Scenario: No lower-layer feature dependency is added
- **WHEN** Windows sub-window plugin safety is implemented
- **THEN** `state`, `application`, and `core` layers SHALL NOT add new imports from `features/*`
- **AND** any window-role or plugin-capability check SHALL remain owned by the feature boundary, a platform seam, or an injected composition-root value

#### Scenario: Regression guardrail covers unsafe WebView entry
- **WHEN** desktop guardrail tests are executed
- **THEN** they SHALL fail if the quick-input sub-window can directly invoke WebView-backed location-picker initialization while WebView plugins remain excluded from sub-window registration
