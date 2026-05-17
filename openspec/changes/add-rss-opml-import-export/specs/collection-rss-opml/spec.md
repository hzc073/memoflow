## ADDED Requirements

### Requirement: OPML import previews RSS subscription changes before commit
The system SHALL parse OPML files into a preview of RSS subscription changes before writing feed or collection state.

#### Scenario: User imports a valid OPML file
- **GIVEN** the user selects an OPML file containing RSS outlines
- **WHEN** the system parses the file
- **THEN** it SHALL show a preview of feeds that can be imported
- **AND** it SHALL show duplicate, invalid, and unresolved entries where applicable
- **AND** it SHALL NOT create memos or RSS articles during preview

#### Scenario: User confirms import
- **GIVEN** an OPML import preview has importable feeds
- **WHEN** the user confirms selected import actions
- **THEN** the system SHALL create or attach RSS feed subscriptions through RSS-owned repository seams
- **AND** imported feeds SHALL be associated with the selected or confirmed collection mapping
- **AND** the system SHALL NOT create memos or RSS articles from OPML

### Requirement: OPML import handles duplicates and malformed entries
The system SHALL classify duplicate and malformed OPML entries without failing the entire import.

#### Scenario: Imported feed already exists
- **GIVEN** an OPML outline references a feed URL already known to the app
- **WHEN** the import preview is generated
- **THEN** the entry SHALL be marked as an existing feed or duplicate
- **AND** confirmation MAY attach the existing feed to the selected collection if it is not already attached
- **AND** it SHALL NOT create a duplicate feed row

#### Scenario: OPML contains invalid entries
- **GIVEN** an OPML file contains malformed XML, missing feed URLs, or unsupported outline entries
- **WHEN** the import flow parses the file
- **THEN** valid entries SHALL remain importable where possible
- **AND** invalid entries SHALL be shown as skipped or unresolved
- **AND** no valid feed import SHALL require creating memos

### Requirement: OPML import supports explicit folder-to-collection mapping
The system SHALL avoid silently creating collection organization from OPML folders without user confirmation.

#### Scenario: OPML contains folders
- **GIVEN** an OPML file contains nested folder outlines
- **WHEN** the import preview is shown
- **THEN** the system SHALL present the folder organization or a flattened result
- **AND** creating new collections from folders SHALL require explicit confirmation
- **AND** mapping folders to existing collections SHALL be visible before commit

### Requirement: OPML export includes subscriptions but excludes content
The system SHALL export RSS subscription metadata and organization to OPML without exporting RSS article or memo content.

#### Scenario: User exports RSS subscriptions
- **GIVEN** the user requests OPML export for a collection or all collections
- **WHEN** the export is generated
- **THEN** the OPML SHALL include feed subscription metadata such as title, feed URL, and site URL when available
- **AND** it SHOULD preserve collection or folder grouping where practical
- **AND** it SHALL NOT include RSS article bodies, read state, saved memo links, memo content, or memo metadata

### Requirement: OPML services preserve architecture boundaries
The OPML import/export change SHALL keep parsing, classification, and commit behavior in service/repository layers rather than UI widgets.

#### Scenario: OPML import is committed
- **WHEN** OPML import writes RSS subscription state
- **THEN** writes SHALL flow through RSS-owned repository or subscription seams
- **AND** feature UI SHALL NOT directly mutate RSS persistence tables
- **AND** no Memos server API compatibility files SHALL be changed
