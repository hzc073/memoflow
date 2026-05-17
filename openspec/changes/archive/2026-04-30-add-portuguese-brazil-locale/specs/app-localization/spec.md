## ADDED Requirements

### Requirement: Brazilian Portuguese locale is supported
The system SHALL support Brazilian Portuguese as a selectable app locale identified by `pt-BR`.

#### Scenario: Generated locales include Brazilian Portuguese
- **WHEN** localization resources are generated from the Slang configuration
- **THEN** the generated app locale list SHALL include a `pt-BR` locale.

#### Scenario: Brazilian Portuguese resource covers app strings
- **WHEN** the app builds generated localization accessors
- **THEN** the Brazilian Portuguese resource SHALL provide the same localization key coverage as the English base resource.

### Requirement: Language selection exposes Brazilian Portuguese
The system SHALL allow users to choose Brazilian Portuguese from every app language selection surface.

#### Scenario: Settings language picker includes Brazilian Portuguese
- **WHEN** the user opens the settings language picker
- **THEN** Brazilian Portuguese SHALL appear as a selectable language option.

#### Scenario: Onboarding language picker includes Brazilian Portuguese
- **WHEN** the user opens the onboarding language selection screen
- **THEN** Brazilian Portuguese SHALL appear as a selectable language option with localized and native labels.

### Requirement: Portuguese device locales resolve to Brazilian Portuguese
The system SHALL resolve Portuguese device/system locales to the Brazilian Portuguese app locale when no more specific Portuguese variant is supported.

#### Scenario: Brazilian Portuguese device locale maps directly
- **WHEN** the device locale is `pt-BR`
- **THEN** the app SHALL use the Brazilian Portuguese app locale.

#### Scenario: Other Portuguese device locale maps to Brazilian Portuguese
- **WHEN** the device locale language code is `pt` and the region is not `BR`
- **THEN** the app SHALL use the Brazilian Portuguese app locale instead of falling back to English.

### Requirement: Brazilian Portuguese copy preserves runtime placeholders
The system SHALL preserve runtime placeholders, interpolation variables, and technical identifiers while rendering Brazilian Portuguese copy.

#### Scenario: Parameterized Portuguese string renders with supplied values
- **WHEN** a Brazilian Portuguese localized string contains a runtime parameter such as a version, count, or error value
- **THEN** the rendered string SHALL include the supplied runtime value without changing the parameter name or breaking interpolation.

#### Scenario: Technical identifiers remain understandable
- **WHEN** Brazilian Portuguese copy references product or protocol terms such as `Memos`, `WebDAV`, `API`, `PAT`, `Markdown`, or `AI`
- **THEN** the copy SHALL preserve those identifiers or use an established Brazilian Portuguese technical equivalent without changing their functional meaning.

### Requirement: Brazilian Portuguese localization is guarded
The system SHALL include focused automated checks for Brazilian Portuguese locale support.

#### Scenario: Locale mapping guardrail is run
- **WHEN** localization tests are executed
- **THEN** they SHALL verify that Portuguese locales map to Brazilian Portuguese and that non-Portuguese existing mappings are not regressed.

#### Scenario: Key label guardrail is run
- **WHEN** localization tests are executed
- **THEN** they SHALL verify representative Brazilian Portuguese labels from common, onboarding, and language-selection copy.
