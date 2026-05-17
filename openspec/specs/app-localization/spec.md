# app-localization Specification

## Purpose
TBD - created by archiving change add-portuguese-brazil-locale. Update Purpose after archive.
## Requirements
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

### Requirement: Korean locale is supported
The system SHALL support Korean as a selectable app locale identified by `ko`.

#### Scenario: Generated locales include Korean
- **WHEN** localization resources are generated from the Slang configuration
- **THEN** the generated app locale list SHALL include a `ko` locale.

#### Scenario: Korean resource covers app strings
- **WHEN** the app builds generated localization accessors
- **THEN** the Korean resource SHALL provide the same localization key coverage as the English base resource.

#### Scenario: Korean locale is exposed to Flutter localization
- **WHEN** `AppLocaleUtils.supportedLocales` is used by `MaterialApp`
- **THEN** the supported locales SHALL include the Flutter locale for Korean.

### Requirement: Language selection exposes Korean
The system SHALL allow users to choose Korean from every app language selection surface.

#### Scenario: Settings language picker includes Korean
- **WHEN** the user opens the settings language picker
- **THEN** Korean SHALL appear as a selectable language option.

#### Scenario: Onboarding language picker includes Korean
- **WHEN** the user opens the onboarding language selection screen
- **THEN** Korean SHALL appear as a selectable language option with localized and native labels.

#### Scenario: Persisted Korean preference remains stable
- **WHEN** the user selects Korean as the app language
- **THEN** the app SHALL persist the preference using the stable value `ko`.

### Requirement: Korean device locales resolve to Korean
The system SHALL resolve Korean device/system locales to the Korean app locale.

#### Scenario: Korean device locale maps directly
- **WHEN** the device locale language code is `ko`
- **THEN** the app SHALL use the Korean app locale.

#### Scenario: Follow System resolves Korean devices to Korean
- **WHEN** the user language preference is `Follow System`
- **AND** the device locale language code is `ko`
- **THEN** the active app locale SHALL be Korean instead of falling back to English.

#### Scenario: Existing locale mappings remain stable
- **WHEN** the device locale language code is `zh`, `ja`, `de`, `pt`, or `en`
- **THEN** the app SHALL keep the existing app locale mapping behavior for that language.

### Requirement: Korean copy preserves runtime placeholders
The system SHALL preserve runtime placeholders, interpolation variables, and technical identifiers while rendering Korean copy.

#### Scenario: Parameterized Korean string renders with supplied values
- **WHEN** a Korean localized string contains a runtime parameter such as a version, count, date, or error value
- **THEN** the rendered string SHALL include the supplied runtime value without changing the parameter name or breaking interpolation.

#### Scenario: Technical identifiers remain understandable
- **WHEN** Korean copy references product or protocol terms such as `Memos`, `MemoFlow`, `WebDAV`, `API`, `PAT`, `Markdown`, `AI`, or server version names
- **THEN** the copy SHALL preserve those identifiers or use an established Korean technical equivalent without changing their functional meaning.

### Requirement: Complete Korean localization covers non-Slang language paths
The system SHALL include Korean behavior for user-visible localization paths that are not fully driven by generated Slang strings.

#### Scenario: Image editor labels are Korean
- **WHEN** the active app language is Korean
- **THEN** image editor package labels SHALL use Korean translations where the app provides an image editor i18n map.

#### Scenario: Sync feedback messages are Korean
- **WHEN** sync feedback is shown while the active app language is Korean
- **THEN** sync success, failure, and progress messages SHALL be Korean.

#### Scenario: Widget locale tags support Korean
- **WHEN** desktop or home widget data is generated for Korean
- **THEN** the locale tag used for localized weekday/date formatting SHALL be `ko`.

#### Scenario: AI language guidance requests Korean
- **WHEN** AI analysis or generation guidance is built for Korean
- **THEN** the prompt guidance SHALL request Korean output instead of defaulting to English or Chinese.

### Requirement: Korean localization preserves module boundaries
The system SHALL add Korean localization without introducing new reverse dependencies or shared-logic leaks across architectural layers.

#### Scenario: Language metadata is shared through a stable helper
- **WHEN** multiple runtime areas need language metadata such as locale tags or week-start behavior
- **THEN** that metadata SHALL be provided through a stable localization helper rather than duplicated feature-specific switches.

#### Scenario: No new high-risk reverse dependency is introduced
- **WHEN** Korean localization is implemented
- **THEN** the change SHALL NOT add new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies.

### Requirement: Korean localization is guarded
The system SHALL include focused automated checks for Korean locale support.

#### Scenario: Locale mapping guardrail is run
- **WHEN** localization tests are executed
- **THEN** they SHALL verify that Korean device locales map to Korean and that existing non-Korean mappings are not regressed.

#### Scenario: Key label guardrail is run
- **WHEN** localization tests are executed
- **THEN** they SHALL verify representative Korean labels from common, onboarding, settings, and language-selection copy.

#### Scenario: Manual path guardrail is run
- **WHEN** localization tests are executed
- **THEN** they SHALL verify at least one representative Korean behavior outside the generated Slang resource path.

### Requirement: Engagement preference copy mentions home memo cards and memo details
The system SHALL provide localized user-visible copy for the engagement preference that makes clear it controls engagement visibility on both home memo cards and memo details, while preserving the existing technical key `showEngagementInAllMemoDetails`.

#### Scenario: Settings surface shows the revised label
- **WHEN** the user opens the preferences screen
- **THEN** the engagement preference label SHALL mention both home memo cards and memo details or an equivalent translation of that scope

#### Scenario: Localized resources preserve the technical key
- **WHEN** localization resources are generated for any supported locale
- **THEN** the backing identifier SHALL remain `showEngagementInAllMemoDetails`
- **AND** each locale SHALL provide translated copy that matches the expanded behavior
