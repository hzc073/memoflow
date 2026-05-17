# server-settings-empty-field-hints Specification

## Purpose
TBD - created by archiving change add-server-limit-empty-field-hints. Update Purpose after archive.
## Requirements
### Requirement: Empty editable server limit fields show field-specific hints
The system SHALL show field-specific placeholder guidance when an editable server settings limit input is empty.

#### Scenario: Empty memo limit field shows supported byte range
- **WHEN** the server settings screen displays a known editable memo content limit value
- **AND** the user focuses the memo content limit input and clears its text
- **THEN** the memo input SHALL show gray placeholder guidance containing the supported byte range
- **AND** the guidance SHALL identify the range as `1-2147483647 bytes`

#### Scenario: Empty attachment limit field shows current MiB limit
- **WHEN** the server settings screen displays a known editable attachment upload limit value
- **AND** the user focuses the attachment upload limit input and clears its text
- **THEN** the attachment input SHALL show gray placeholder guidance containing the current server-confirmed attachment limit
- **AND** the guidance SHALL identify the unit as MiB

#### Scenario: Entering a value hides the placeholder
- **WHEN** an editable server limit input is empty and showing placeholder guidance
- **AND** the user enters numeric text into that input
- **THEN** the placeholder guidance SHALL no longer be visible in that input

#### Scenario: Blurring an empty field restores the server value
- **WHEN** an editable server limit input has a known server-confirmed value
- **AND** the user clears the input text
- **AND** the input loses focus before a valid new value is saved
- **THEN** the input SHALL restore the server-confirmed value
- **AND** the system SHALL NOT treat the empty text as an update request

#### Scenario: Unavailable settings do not invent placeholder hints
- **WHEN** a server limit field is unavailable, unsupported, permission denied, or otherwise lacks a known value
- **THEN** the field SHALL NOT show a fabricated placeholder
- **AND** existing unavailable, unsupported, or permission guidance SHALL remain the source of user feedback

