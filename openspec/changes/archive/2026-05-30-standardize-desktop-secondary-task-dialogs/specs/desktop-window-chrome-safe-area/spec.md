## ADDED Requirements

### Requirement: Desktop task surfaces SHALL avoid native window controls through shared chrome seams

桌面任务表面 SHALL use shared desktop chrome safe-area seams or platform dialog geometry so title, close/cancel affordances, first interactive controls, and action bars do not overlap native or custom window controls. Feature pages SHALL NOT solve this by hardcoding macOS traffic-light coordinates or platform-specific padding.

#### Scenario: macOS task surface is shown from the main window
- **WHEN** a desktop task surface is shown on macOS from a main window that has visible native traffic lights
- **THEN** the task title, close/cancel affordance, and first interactive controls SHALL be laid out outside the traffic-light reserved area
- **AND** the task surface SHALL NOT place a feature-owned back button under the red/yellow/green controls

#### Scenario: Windows or Linux task surface is shown
- **WHEN** a desktop task surface is shown on Windows or Linux
- **THEN** the surface SHALL preserve the platform's existing window-control behavior
- **AND** it SHALL NOT apply macOS-only traffic-light leading inset unless that platform chrome mode explicitly declares an equivalent reserved area

#### Scenario: Feature task content is migrated
- **WHEN** a feature task screen is migrated into a shared desktop task surface
- **THEN** the feature task content SHALL provide semantic content and actions
- **AND** the shared surface or shell SHALL own native window-control avoidance
