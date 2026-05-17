# app-localization Specification

## Purpose

Keep localized user-visible copy aligned with the behaviors exposed by the app settings and interaction surfaces.

## ADDED Requirements

### Requirement: Engagement preference copy mentions home memo cards and memo details
The system SHALL provide localized user-visible copy for the engagement preference that makes clear it controls engagement visibility on both home memo cards and memo details, while preserving the existing technical key `showEngagementInAllMemoDetails`.

#### Scenario: Settings surface shows the revised label
- **WHEN** the user opens the preferences screen
- **THEN** the engagement preference label SHALL mention both home memo cards and memo details or an equivalent translation of that scope

#### Scenario: Localized resources preserve the technical key
- **WHEN** localization resources are generated for any supported locale
- **THEN** the backing identifier SHALL remain `showEngagementInAllMemoDetails`
- **AND** each locale SHALL provide translated copy that matches the expanded behavior
