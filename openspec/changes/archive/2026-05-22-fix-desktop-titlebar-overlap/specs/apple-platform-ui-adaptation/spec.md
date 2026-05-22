## ADDED Requirements

### Requirement: macOS Apple shell SHALL respect native traffic-light chrome
The system SHALL treat macOS native traffic lights as reserved window chrome when Apple shell content is drawn into a transparent or full-size titlebar region.

#### Scenario: Apple shell titlebar content is offset
- **WHEN** `AppleMacosPageShell` or an equivalent macOS shell renders top-leading titlebar, toolbar, navigation, or command content
- **THEN** that content MUST be offset, constrained, or otherwise laid out so it does not overlap native red/yellow/green window controls

#### Scenario: Apple shell uses centralized chrome metrics
- **WHEN** macOS shell code needs traffic-light spacing
- **THEN** it SHALL use the desktop window chrome safe-area seam rather than embedding unrelated page-specific padding in feature widgets

