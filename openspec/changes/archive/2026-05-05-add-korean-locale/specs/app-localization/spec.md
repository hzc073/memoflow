## ADDED Requirements

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
