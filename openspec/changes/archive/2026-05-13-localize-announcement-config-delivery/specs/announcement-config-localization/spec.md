## ADDED Requirements

### Requirement: Locale-scoped announcement content

Update announcement source content SHALL be authorable as locale-scoped files where each file declares exactly one locale and contains only content for that locale.

#### Scenario: Locale file contains only its declared language

- **GIVEN** a localized announcement source file declares `locale: "ja"`
- **WHEN** the config manager validates the source file
- **THEN** the file SHALL NOT contain sibling localized maps such as `zh`, `en`, or `pt-BR`
- **AND** the file SHALL store title, summary, and item content as single-locale content.

#### Scenario: Delivery controls remain language-neutral

- **GIVEN** an update or notice candidate targets platform, channel, status, schedule, priority, or dismissal behavior
- **WHEN** localized announcement files are generated or edited
- **THEN** those delivery controls SHALL remain in the language-neutral manifest/candidate layer
- **AND** localized content files SHALL NOT duplicate channel, platform, status, publish, expire, or dismissal policy fields.

### Requirement: Locale-specific client outputs

The build pipeline SHALL generate locale-specific update config outputs for modern clients.

#### Scenario: Modern output declares its locale

- **GIVEN** the build pipeline generates `latest.pt-BR.json`
- **WHEN** the file is loaded
- **THEN** it SHALL include a top-level locale marker equivalent to `pt-BR`
- **AND** it SHALL include delivery metadata and announcement content suitable for that locale.

#### Scenario: Client rejects mismatched locale payload

- **GIVEN** the app requests an English config
- **WHEN** the fetched payload declares `locale: "de"`
- **THEN** the app SHALL reject that payload for English delivery
- **AND** it SHALL continue to another configured source or fallback path instead of showing German content as English.

### Requirement: English fallback for missing locale content

When content for the requested locale is missing, the system SHALL use English as the default fallback.

#### Scenario: Requested locale is missing but English exists

- **GIVEN** the app requests `ko` announcement content
- **AND** the `ko` localized content is missing or empty
- **AND** English content exists for the same announcement id
- **WHEN** the candidate is otherwise eligible
- **THEN** the app SHALL render the English content.

#### Scenario: English fallback is missing

- **GIVEN** the app requests `de` announcement content
- **AND** the `de` localized content is missing or empty
- **AND** English content is also missing or empty
- **WHEN** the candidate is evaluated
- **THEN** the candidate SHALL be treated as not displayable
- **AND** the app SHALL NOT display content from an arbitrary other locale.

### Requirement: v2 compatibility without v1 compatibility

The localized announcement delivery pipeline SHALL preserve v2-compatible output for old clients and SHALL NOT be required to preserve v1 compatibility.

#### Scenario: v2-compatible default output remains available

- **GIVEN** localized source files are used for modern announcement delivery
- **WHEN** the build pipeline runs
- **THEN** it SHALL still generate a v2-compatible default output such as `latest.json`
- **AND** that output SHALL preserve the legacy fields needed by v2 clients, including `version_info`, `announcement`, `release_notes`, `notice_enabled`, and `notice` where applicable.

#### Scenario: v1-only source shape is not accepted

- **GIVEN** a source config only matches a v1 announcement/update shape
- **WHEN** the localized delivery validator evaluates it
- **THEN** the validator SHALL reject it or exclude it from localized output generation
- **AND** the implementation SHALL NOT add migration behavior solely to preserve v1 clients.

### Requirement: AI-assisted translation remains draft-first

AI translation support SHALL be a local config manager authoring aid and SHALL NOT automatically publish translated content.

#### Scenario: AI generates localized drafts

- **GIVEN** a reviewed Chinese source announcement exists
- **WHEN** the operator requests AI translation to target locales
- **THEN** the local config manager MAY create or update target locale draft files
- **AND** those files SHALL record source locale, source content hash, and translation review status.

#### Scenario: Source changes mark translations stale

- **GIVEN** a translated locale file records a source hash
- **WHEN** the Chinese source announcement changes and the source hash no longer matches
- **THEN** the config manager SHALL mark that translation stale or surface a validation warning/blocker before publish.

#### Scenario: AI provider settings are not published

- **GIVEN** the local config manager uses an AI provider to draft translations
- **WHEN** build output is generated for public hosting
- **THEN** API keys, provider URLs, local prompts, and operator-only AI settings SHALL NOT appear in generated public update config.

