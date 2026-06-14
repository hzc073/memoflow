# settings-subpage-platformization Specification

## Purpose
TBD - created by archiving change platformize-settings-subpages. Update Purpose after archive.
## Requirements
### Requirement: Settings subpages SHALL avoid raw Material-only controls in Apple mobile settings content

Migrated settings subpages SHALL use settings/platform semantic seams for controls that appear inside Apple mobile settings content and SHALL NOT directly embed Material-only controls that require a `Material` ancestor inside `CupertinoListSection`, `CupertinoListTile`, `SettingsSection`, or equivalent Apple grouped-list content.

#### Scenario: Location settings precision renders on iPhone

- **WHEN** 用户在 iPhone 上打开 location settings
- **THEN** location precision selection SHALL render without `No Material widget found`
- **AND** changing precision SHALL keep the existing `locationSettingsProvider` mutation behavior

#### Scenario: Toolbar custom icon group renders on iPhone

- **WHEN** 用户在 iPhone 上打开 memo toolbar custom button editor
- **THEN** icon group selection SHALL render through a settings/platform choice seam
- **AND** choosing a group SHALL update the visible icon options without Flutter framework errors

#### Scenario: Checkbox and radio settings render through semantic seams

- **WHEN** migrated settings subpages render checkbox or radio choices
- **THEN** they SHALL use settings/platform single-choice or multi-choice seams
- **AND** they SHALL NOT directly place `CheckboxListTile` or `RadioListTile` in Apple mobile grouped-list content

### Requirement: Settings subpage transient UI SHALL use platform presentation seams

Migrated settings subpages SHALL present confirmation dialogs, destructive prompts, option pickers, sheets, and feedback through platform/settings seams rather than raw Material presentation APIs unless the surface is explicitly documented as a Material-only desktop/task exception.

#### Scenario: Confirmation prompt opens on iPhone

- **WHEN** a migrated settings subpage opens a confirm/delete/reset prompt on iPhone
- **THEN** the prompt SHALL use `showPlatformAlertDialog`, `showPlatformDialog`, or an approved equivalent
- **AND** destructive/default action semantics SHALL be preserved

#### Scenario: Option picker opens on iPhone

- **WHEN** a migrated settings subpage asks users to choose an enum, schedule, auth mode, export format, model filter, or similar option
- **THEN** it SHALL use `showPlatformPicker`, settings choice row, or an approved platform picker/action sheet seam
- **AND** selecting an option SHALL preserve the existing callback/provider mutation path

#### Scenario: Settings subpage route opens on Apple mobile

- **WHEN** a migrated settings subpage pushes another settings or task page on iPhone/iPadOS
- **THEN** it SHALL use `buildPlatformPageRoute` or an approved platform route seam
- **AND** Apple back gesture and route transition behavior SHALL be preserved

### Requirement: Settings subpage migration SHALL preserve business semantics

Settings subpage platformization SHALL be UI-only except where a small extraction is needed to route presentation through existing seams. It MUST NOT change API adapters, WebDAV protocol behavior, database schema, sync semantics, backup archive format, AI provider/model semantics, or migration data format.

#### Scenario: WebDAV settings are migrated

- **WHEN** `WebDavSyncScreen` controls, dialogs, choices, or actions are migrated
- **THEN** existing WebDAV auth mode, backup schedule, encryption, vault, restore, sync, and backup service behavior SHALL remain unchanged
- **AND** the change MUST NOT modify WebDAV protocol request/response behavior

#### Scenario: AI settings are migrated

- **WHEN** AI provider, model, detail, wizard, route, proxy, or user-profile settings surfaces are migrated
- **THEN** provider/model/route persistence, validation, default route semantics, and existing AI settings repositories SHALL remain unchanged
- **AND** platformization SHALL not add commercial/private capability checks

#### Scenario: Migration settings are migrated

- **WHEN** MemoFlow migration sender, receiver, method, role, or result settings surfaces are migrated
- **THEN** migration session, receiver, sender, QR/proposal, progress, and data transfer semantics SHALL remain unchanged
- **AND** only UI presentation seams SHALL change

### Requirement: Settings subpage migration SHALL be covered by inventory, guardrails, and tests

The migration SHALL maintain a reviewable inventory and automated or semi-automated guardrails so migrated settings files do not reintroduce high-risk raw Material-only controls.

#### Scenario: Migration inventory is updated

- **WHEN** implementation begins
- **THEN** the change SHALL create or update an inventory listing migrated, pending, deferred, and exception settings files
- **AND** each completed batch SHALL update that inventory

#### Scenario: Migrated file guardrail runs

- **WHEN** architecture or settings UI guardrail tests run
- **THEN** migrated settings files SHALL fail or warn if they introduce direct `ChoiceChip`, `FilterChip`, `ActionChip`, `InputChip`, `DropdownButton`, `RadioListTile`, `CheckboxListTile`, raw `MaterialPageRoute`, or raw Material dialog/sheet APIs in high-risk contexts
- **AND** exceptions SHALL require a documented allowlist entry

#### Scenario: iOS smoke coverage runs

- **WHEN** focused settings tests run
- **THEN** migrated settings subpages SHALL have iOS smoke or focused widget coverage
- **AND** tests SHALL assert no `No Material widget found` or equivalent Flutter framework exception is thrown

### Requirement: Settings subpage platformization SHALL preserve public and modular boundaries

The migration SHALL reduce settings UI coupling by using shared settings/platform seams and MUST NOT introduce new lower-layer dependencies on feature UI or public/private commercial leakage.

#### Scenario: No reverse dependency is introduced

- **WHEN** settings subpages are migrated
- **THEN** `state`, `application`, `core`, and `platform` layers MUST NOT add new imports from `features/settings` or other `features/*` UI files
- **AND** shared control behavior SHALL live in settings/platform seams rather than page-private reusable logic

#### Scenario: Public repository remains commercial-free

- **WHEN** settings subpage platformization is implemented
- **THEN** it MUST NOT add subscription, billing, entitlement, receipt, paywall, StoreKit, product ID, price, private overlay, or `AccessDecision.source` business branching logic

### Requirement: Migrated settings subpages SHALL use aligned field seams for full-width inputs

Migrated settings subpages SHALL render long text、password、secret/key 和 multiline settings fields through aligned settings field seams rather than page-private field layouts or subtitle-based filled inputs that visually drift from section containers.

#### Scenario: Network and provider credential fields are aligned

- **WHEN** `AiProxySettingsScreen` renders password 或 test URL fields
- **THEN** those fields SHALL use the aligned full-width settings field block seam
- **AND** proxy protocol、host、port、username、test action 和 save behavior SHALL preserve existing state and callback behavior

#### Scenario: Image bed credential fields are aligned

- **WHEN** `ImageBedSettingsScreen` renders API URL、password 或 equivalent credential fields
- **THEN** those fields SHALL use the aligned full-width settings field block seam
- **AND** provider selection、base URL normalization、email、strategy ID、retry settings 和 `imageBedSettingsProvider` writes SHALL preserve existing behavior

#### Scenario: Location provider key fields are aligned

- **WHEN** `LocationSettingsScreen` renders AMap Web API Key、AMap Security Key、Baidu AK、Google API Key 或 equivalent provider key fields
- **THEN** those fields SHALL use the aligned full-width settings field block seam
- **AND** provider selection、precision selection、dirty state 和 provider notifier writes SHALL remain unchanged

#### Scenario: Multiline settings-adjacent fields are aligned

- **WHEN** `AiUserProfileScreen`、`ExportLogsScreen` 或 `CustomNotificationScreen` renders multiline profile、notes、body 或 equivalent fields
- **THEN** those fields SHALL use the aligned multiline settings field seam
- **AND** maxLength、minLines、maxLines、preview behavior、save behavior 和 existing controller callbacks SHALL remain unchanged

### Requirement: Settings field alignment SHALL preserve business and public boundaries

Settings field alignment SHALL be a presentation-only migration. It SHALL NOT change persistence keys, provider ownership, API adapters, WebDAV protocol, sync behavior, reminder scheduling, database schema, private extension boundaries, or commercial logic.

#### Scenario: Presentation migration preserves settings owners

- **WHEN** settings pages are migrated from old form rows to aligned field block seams
- **THEN** existing controllers、onChanged callbacks、onEditingComplete callbacks、validation rules、normalization helpers 和 provider notifiers SHALL continue to own their current behavior
- **AND** the migration SHALL NOT introduce new state owners or move business/domain logic into reusable UI widgets

#### Scenario: Public repository remains commercial-free

- **WHEN** this alignment change touches settings or settings-adjacent public files
- **THEN** it MUST NOT add subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、purchase、private overlay 或 `AccessDecision.source` business branching logic
- **AND** it SHALL NOT modify private hooks or public/private extension seams

#### Scenario: API and data layers are untouched

- **WHEN** implementing this change
- **THEN** files under `memos_flutter_app/lib/data/api` and `memos_flutter_app/test/data/api` SHALL NOT be edited
- **AND** WebDAV service/repository/model、database schema 和 persistence keys SHALL remain unchanged

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
