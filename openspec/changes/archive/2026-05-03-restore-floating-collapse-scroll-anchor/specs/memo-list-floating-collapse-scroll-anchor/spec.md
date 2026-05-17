## ADDED Requirements

### Requirement: Floating collapse restores the collapsed memo anchor
The memo list SHALL restore the viewport to the active memo's collapsed card anchor after the user activates the floating collapse action for that memo.

#### Scenario: Expanded first memo returns to its collapsed card
- **WHEN** the list contains memos A, B, and C
- **AND** memo A is expanded
- **AND** the user scrolls deep enough through memo A that the current viewport is near memo B
- **AND** the floating collapse action is visible for memo A
- **AND** the user activates the floating collapse action
- **THEN** memo A is collapsed
- **AND** the viewport is restored so memo A's collapsed card is visible
- **AND** the viewport does not remain at a later offset that lands on memo C

#### Scenario: Anchor target is clamped after collapse
- **WHEN** the user activates the floating collapse action for an expanded memo
- **AND** the memo's captured card anchor is greater than the post-collapse scroll extent
- **THEN** the memo list restores to the nearest valid scroll offset
- **AND** no scroll exception is thrown

#### Scenario: Missing anchor skips restoration safely
- **WHEN** the user activates the floating collapse action
- **AND** the active memo card state, card render object, or scroll controller is unavailable
- **THEN** the memo list still attempts to collapse the active memo when possible
- **AND** the memo list does not throw

### Requirement: Inline collapse behavior remains unchanged
The memo list SHALL limit this anchor restoration behavior to the floating collapse action and SHALL preserve existing inline memo card expand and collapse behavior.

#### Scenario: Inline collapse does not use floating anchor restoration
- **WHEN** the user activates the inline `Collapse` control inside an expanded memo card
- **THEN** the memo card collapses using the existing inline toggle behavior
- **AND** the floating-collapse anchor restoration flow is not invoked
