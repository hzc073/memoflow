## ADDED Requirements

### Requirement: Desktop memo list layout SHALL not hide shared desktop behavior behind Windows-only gates

Desktop memo list card-width and preview-pane behavior SHALL be expressed as desktop layout behavior unless a platform-specific exception is explicitly documented.

#### Scenario: Shared desktop card width
- **WHEN** a memo card is rendered in a desktop target memo list
- **THEN** it MUST use the shared desktop memo card maximum width rather than a Windows-only width constraint

#### Scenario: Shared desktop media tile proportions
- **WHEN** a memo media grid is rendered in a desktop target memo surface and its configured max height is smaller than its unconstrained square grid height
- **THEN** the grid MUST preserve square tile proportions by shrinking tile width and height together
- **AND** this behavior MUST NOT be limited to Windows-only platform checks

#### Scenario: Shared desktop preview support
- **WHEN** a desktop target reaches the configured memo preview pane breakpoint
- **THEN** the memo list MUST consider the preview pane supported for that platform
- **AND** platform-specific shell code MAY still decide exact chrome, thresholds, and default visibility where documented
