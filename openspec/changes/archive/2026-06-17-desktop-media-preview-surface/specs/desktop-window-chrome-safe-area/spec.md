## ADDED Requirements

### Requirement: Desktop media preview roots SHALL avoid native window controls

Desktop media preview roots SHALL place viewer controls, status, and interactive hit areas outside platform-owned window controls whenever media content or chrome can extend into the titlebar region. Media preview code SHALL use shared chrome safe-area seams rather than feature-local magic padding.

#### Scenario: macOS dedicated media window renders controls
- **WHEN** a desktop media preview surface runs in a macOS window with native red/yellow/green controls visible
- **THEN** page count, close affordance if present, previous/next controls, download/edit actions, status text, and first top-leading hit areas SHALL NOT overlap the traffic-light reserved area
- **AND** any top or leading control placement SHALL use the shared desktop chrome safe-area seam or an equivalent window-root wrapper.

#### Scenario: Main-window immersive fallback renders controls
- **WHEN** a desktop media preview uses the main-window immersive fallback on macOS
- **THEN** viewer controls SHALL avoid the native traffic-light and titlebar hit areas
- **AND** the fallback SHALL NOT solve this by hardcoding macOS traffic-light coordinates inside `features/image_preview` or `features/memos` widget layout.

#### Scenario: Non-macOS media window preserves platform behavior
- **WHEN** a desktop media preview surface runs on Windows or Linux
- **THEN** it SHALL preserve the platform's existing window-control behavior
- **AND** it SHALL NOT apply macOS-only leading inset unless that platform chrome mode explicitly declares an equivalent reserved window-control area.

#### Scenario: Chrome guardrail covers media viewer
- **WHEN** desktop media preview root chrome, window root, or viewer control placement is changed
- **THEN** focused widget tests, layout tests, smoke checklist entries, or architecture guardrails SHALL verify macOS traffic-light avoidance
- **AND** at least one non-macOS or mobile fallback behavior SHALL be verified or documented as unchanged.
