# memo-card-press-feedback Specification

## Purpose

Define memo list card press feedback so pressing short and tall memo cards uses the same fixed, minimal visual movement without proportional full-card scaling.

## Requirements

### Requirement: Memo card press feedback uses fixed minimal motion
The memo list card press feedback SHALL use a fixed-size visual movement that is independent of the card height, and it MUST NOT apply proportional full-card scaling to the memo card surface.

#### Scenario: Tall memo card press does not create large visual gaps
- **WHEN** a user presses a tall memo card in the memo list
- **THEN** the card uses only a fixed minimal press movement of no more than one logical pixel
- **AND** the movement is not proportional to the memo card height

#### Scenario: Short memo card and tall memo card use the same press displacement
- **WHEN** a user presses memo cards with different rendered heights
- **THEN** each pressed card uses the same fixed displacement
- **AND** taller cards do not visibly shrink more than shorter cards

### Requirement: Memo card interactions remain unchanged
The memo list card press feedback SHALL preserve the existing memo card interaction semantics.

#### Scenario: Existing gestures still route to their current actions
- **WHEN** a user taps, double-taps, long-presses, right-clicks, or cancels a press on a memo card
- **THEN** the existing memo card callbacks continue to run as before
- **AND** the press feedback does not consume or replace those gesture behaviors

#### Scenario: Non-memo controls keep their existing press feedback
- **WHEN** a user presses buttons, drawer items, preview-pane action buttons, search controls, or other non-memo-card controls
- **THEN** those controls keep their existing press feedback behavior unless they explicitly opt into a separate change

### Requirement: Memo card press feedback respects reduced motion
The memo list card press feedback SHALL respect the app's reduced-motion handling.

#### Scenario: Reduced motion disables transition animation
- **WHEN** platform or app accessibility settings disable animations
- **THEN** memo card press feedback transition duration is zero
- **AND** no new animated press transition is introduced for that user setting
