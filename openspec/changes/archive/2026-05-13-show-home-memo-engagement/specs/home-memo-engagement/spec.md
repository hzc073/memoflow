# home-memo-engagement Specification

## Purpose

Define how home memo list cards present and operate likes/comments when engagement display is enabled.

## ADDED Requirements

### Requirement: Home memo cards show engagement previews when enabled
The system SHALL render a home-card engagement preview with liker avatars and recent comment content when the engagement preference is enabled.

#### Scenario: Memo with existing likes shows liker avatars
- **WHEN** a memo appears on the home memo list and it already has one or more likes or comments
- **THEN** the card SHALL display concrete liker avatars for recent likers
- **AND** the preview SHALL cap visible avatars to a small fixed number
- **AND** the preview SHALL indicate when additional people liked the memo beyond the visible avatars

#### Scenario: Memo with existing comments shows recent comment content
- **WHEN** a memo appears on the home memo list and it already has comments
- **THEN** the card SHALL display the latest one to two comment entries
- **AND** the preview SHALL include comment text content instead of only a numeric comment count
- **AND** when more comments exist than are previewed, the card SHALL expose a "view all comments" affordance that opens the existing comment surface

#### Scenario: Memo without engagement shows compact zero-state
- **WHEN** a memo appears on the home memo list and it has no likes and no comments
- **THEN** the card SHALL still show a compact engagement affordance
- **AND** the affordance SHALL not expand into a full comment thread by default

### Requirement: Home memo cards allow engagement actions without opening detail first
The system SHALL let users like and comment from the home memo card engagement surface without requiring navigation to `MemoDetailScreen` first.

#### Scenario: Like action toggles from the card surface
- **WHEN** the user taps the like control on a home memo card engagement surface
- **THEN** the system SHALL toggle the memo like state for the current user
- **AND** the visible likes count or state SHALL update to reflect the action

#### Scenario: Comment action opens a comment composer
- **WHEN** the user taps the comment control on a home memo card engagement surface
- **THEN** the system SHALL open a comment composer or shared engagement surface for that memo
- **AND** the user SHALL be able to submit a comment without first opening `MemoDetailScreen`

#### Scenario: View all comments opens the existing surface
- **WHEN** the user taps the home card affordance for viewing all comments
- **THEN** the system SHALL open the existing comment surface for that memo
- **AND** the detail page behavior and the existing comment bottom-sheet experience SHALL remain unchanged

### Requirement: Home engagement follows the same preference gate as detail engagement
The system SHALL use the existing engagement preference to determine whether home memo cards display the engagement surface.

#### Scenario: Preference disabled hides home engagement
- **WHEN** the engagement preference is disabled
- **THEN** home memo cards SHALL not show the engagement summary or action surface

#### Scenario: Preference enabled shows engagement on home and detail
- **WHEN** the engagement preference is enabled
- **THEN** home memo cards SHALL show the engagement preview
- **AND** memo details SHALL continue to show engagement as before
