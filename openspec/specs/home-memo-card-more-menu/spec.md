# home-memo-card-more-menu Specification

## Purpose
TBD - created by archiving change restyle-home-memo-card-more-menu. Update Purpose after archive.
## Requirements

### Requirement: Home memo more menu opens as an anchored popover
The system SHALL open the home memo card more menu as a custom floating popover anchored to the triggering card action button or secondary-click position, and it MUST NOT present the menu as the default flat `PopupMenuButton` list.

#### Scenario: User taps the card more button
- **WHEN** the user taps the top-right more button on a home memo card
- **THEN** the system shows a floating action popover near that card's more button
- **AND** the card action behavior continues to route through the existing `MemoCardAction` selection flow

#### Scenario: User secondary-clicks a memo card on Windows
- **WHEN** the user opens the memo card context menu with a Windows secondary-click
- **THEN** the system shows the same floating action popover style near the secondary-click position
- **AND** selecting an action returns the corresponding `MemoCardAction`

### Requirement: Normal memo actions are grouped by intent
The system SHALL group normal memo actions into a primary icon grid, a secondary more-settings section, and a visually separated destructive section.

#### Scenario: Normal memo menu is shown
- **WHEN** the more menu opens for a normal memo
- **THEN** copy, edit, reminder, pin or unpin, add to collection, and archive appear as primary icon-and-label actions
- **AND** change created time and view history appear under a localized more-settings section
- **AND** delete appears in a separate destructive section

### Requirement: Archived memo menu uses the archived action subset
The system SHALL keep archived memo action availability limited to the existing archived actions while using the same popover visual language.

#### Scenario: Archived memo menu is shown
- **WHEN** the more menu opens for an archived memo
- **THEN** copy, view history, restore, and delete are available
- **AND** normal-only actions such as edit, reminder, pin or unpin, add to collection, archive, and change created time are not shown
- **AND** delete remains visually separated as a destructive action

### Requirement: Popover positioning remains viewport-safe
The system SHALL keep the memo action popover fully visible within the current overlay viewport when space allows, including near the top, right, bottom, and left screen edges.

#### Scenario: More button is near the right edge
- **WHEN** the user opens the more menu from a card whose more button is near the right edge of the viewport
- **THEN** the popover shifts or clamps horizontally so its content remains visible

#### Scenario: More button is near the bottom edge
- **WHEN** the user opens the more menu from a card whose more button is near the bottom edge of the viewport
- **THEN** the popover shifts or clamps vertically so its content remains visible

### Requirement: Menu dismissal preserves existing action semantics
The system SHALL close the memo action popover when the user selects an action, taps outside the popover, or uses the platform back or escape dismissal path, without changing the selected action's existing behavior.

#### Scenario: User selects an action
- **WHEN** the user selects copy, edit, reminder, pin or unpin, add to collection, archive, restore, change created time, view history, or delete from the popover
- **THEN** the popover closes
- **AND** the caller receives exactly one matching `MemoCardAction`

#### Scenario: User dismisses without selecting
- **WHEN** the user taps outside the popover or dismisses it through the platform back or escape path
- **THEN** the popover closes
- **AND** no `MemoCardAction` is emitted
