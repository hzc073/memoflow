## MODIFIED Requirements

### Requirement: Apple shell differentiation

The system SHALL provide differentiated Apple shell strategies for iOS, iPadOS, and macOS while reusing existing business state and destination models.

#### Scenario: macOS memo list uses desktop card and preview behavior
- **WHEN** the app runs on macOS in a wide desktop home memo list layout
- **THEN** memo cards MUST remain bounded to the shared desktop memo card maximum width
- **AND** memo card media tiles MUST avoid height-limited horizontal stretching by preserving desktop square tile proportions when the media grid is capped by available height
- **AND** tapping a memo card SHOULD open or update the desktop preview pane instead of navigating directly to the full detail route
- **AND** the implementation MUST reuse the existing memo list preview state and desktop layout seams instead of creating macOS-only memo state
