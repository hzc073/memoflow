## ADDED Requirements

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
