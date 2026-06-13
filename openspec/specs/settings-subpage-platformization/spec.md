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
