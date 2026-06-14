## ADDED Requirements

### Requirement: Migrated settings subpages SHALL use settings-owned layout seams

Migrated settings subpages SHALL render reusable section、row、field、divider 和 card hierarchy through settings-owned layout seams. They SHALL NOT reintroduce page-private row shells, field cards, raw text fields, or platform-default list row geometry for ordinary settings presentation.

#### Scenario: Settings rows use shared row geometry

- **WHEN** a migrated settings subpage renders navigation row、value row、toggle row、menu row、info row、action row 或 selectable row
- **THEN** the row SHALL use `SettingsNavigationRow`, `SettingsValueRow`, `SettingsToggleRow`, `SettingsMenuRow`, `SettingsInfoRow`, `SettingsAction`, a shared settings row shell, or an approved settings seam
- **AND** title/value/description/trailing layout SHALL be controlled by the settings seam rather than page-local row wrappers

#### Scenario: Settings sections use shared section hierarchy

- **WHEN** a migrated settings subpage renders grouped content on iPhone, Android, desktop, or web
- **THEN** section margin、background、border、radius、divider 和 spacing SHALL be controlled by `SettingsSection`, a settings-owned section seam, or approved settings tokens
- **AND** page-local ordinary section/card surface styling SHALL require an explicit documented exception

#### Scenario: Settings subpage avoids local field surfaces

- **WHEN** a migrated settings subpage renders text input, password input, API key input, URL input, path input, multiline text, or inline fallback input
- **THEN** it SHALL use `SettingsFieldBlock`, `SettingsFormFieldRow`, `SettingsMultilineFieldRow`, `SettingsInlineTextFieldRow`, `SettingsNumericInlineFieldRow`, `PlatformTextField` through an approved settings seam, or equivalent shared settings component
- **AND** it SHALL NOT create page-local `_FieldBlock`, `_InputCard`, raw `TextField`, `TextFormField`, `CupertinoTextField`, or `InputBorder.none` input surface for ordinary settings fields

### Requirement: Settings subpage layout unification SHALL preserve behavior and ownership

Settings layout unification SHALL be presentation-only. It SHALL preserve existing controllers、callbacks、provider mutations、validation、normalization、save/test behavior、navigation targets、WebDAV behavior、API behavior、database schema、persistence keys、private boundaries 和 commercial-free public shell constraints.

#### Scenario: WebDAV settings behavior is preserved

- **WHEN** WebDAV settings or the server connection subpage adopts unified settings layout
- **THEN** existing server URL、username、password、auth mode、root path、TLS warning/switch、save、test connection、sync、backup、restore 和 schedule behavior SHALL remain unchanged
- **AND** WebDAV service/repository/model、protocol request/response behavior、database schema 和 persistence keys SHALL NOT be modified by the layout migration

#### Scenario: Credential and provider pages preserve state owners

- **WHEN** AI proxy、image bed、location settings、server settings 或 similar credential/provider settings adopt unified settings layout
- **THEN** existing Provider/Riverpod owners、controllers、normalization、validation、save callbacks 和 field semantics SHALL remain unchanged
- **AND** reusable visual behavior SHALL stay in settings/platform seams rather than moving into state、application、core、data 或 page-private reusable logic

#### Scenario: Reminder and notification settings preserve callbacks

- **WHEN** custom notification、reminder settings、shortcut editor 或 similar settings-adjacent pages adopt unified settings layout
- **THEN** existing preview、save、maxLength、inputFormatters、route result 和 callback behavior SHALL remain unchanged
- **AND** adaptive picker/dialog/back behavior SHALL continue through platform/settings seams

#### Scenario: Public and private boundaries are preserved

- **WHEN** unified settings layout is implemented in public repository files
- **THEN** it MUST NOT add subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching
- **AND** it SHALL NOT modify private hooks or public/private extension seams

### Requirement: Settings layout drift SHALL be guarded

The settings subpage platformization guardrails SHALL prevent migrated settings files from drifting back to page-local layout, raw input controls, direct platform list geometry, or unapproved local surface styling.

#### Scenario: Migrated file introduces local layout surface

- **WHEN** a migrated settings file adds page-local row shell, field block, input card, grouped card, divider, raw palette surface, or ordinary settings background/border styling outside approved settings seams
- **THEN** architecture/style verification SHALL fail or require an explicit documented exception
- **AND** the exception SHALL explain why the surface is semantic preview/error/media/native/system UI rather than ordinary settings layout

#### Scenario: Migrated file introduces raw platform form controls

- **WHEN** a migrated settings file adds raw `TextField`, `TextFormField`, `CupertinoTextField`, bare `Switch`, `Switch.adaptive`, raw Material/Cupertino picker/dialog/list APIs, or direct `PlatformListSection` for ordinary settings content
- **THEN** guardrail verification SHALL fail or require an explicit documented exception
- **AND** reusable behavior SHALL be moved to settings/platform seams when the control is ordinary settings UI

#### Scenario: Cross-platform layout behavior is tested

- **WHEN** focused settings UI tests run
- **THEN** representative settings rows and fields SHALL verify title/value/description hierarchy、field block geometry、section hierarchy 和 adaptive control presence on at least iPhone and Android contexts where feasible
- **AND** tests SHALL verify no Flutter framework exception is thrown
