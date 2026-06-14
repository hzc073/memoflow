## MODIFIED Requirements

### Requirement: WebDAV settings pages SHALL use semantic settings UI seams

WebDAV settings surfaces in `webdav_sync_screen.dart` SHALL render page chrome, grouped rows, toggles, navigation entries, input rows, action buttons, status/progress rows, warning/copy rows, and log entries through `SettingsPage`, `SettingsSection`, semantic settings rows/actions, or equivalent settings/platform seams instead of direct palette/local card/button/toggle implementations. `_WebDavConnectionScreen` SHALL also present connection settings with clear grouped hierarchy, user-facing copy, and theme-derived colors without changing WebDAV persistence or network behavior.

#### Scenario: WebDAV root page is migrated

- **WHEN** `WebDavSyncScreen` renders enable sync, connection entry, backup strategy entry, Vault security status entry, logs entry, backup/restore actions, progress state, or sync error copy
- **THEN** it SHALL use settings semantic page/section/row/action seams
- **AND** it SHALL preserve enable/disable writes, navigation targets, manual sync, backup now, restore backup, progress pause/resume, sync error presentation, and existing provider/service call paths

#### Scenario: WebDAV connection page is migrated

- **WHEN** `_WebDavConnectionScreen` renders server URL, username, password, auth mode, ignore TLS, root path, warning copy, or connection test action
- **THEN** it SHALL use settings semantic page/section/input/toggle/value/action seams
- **AND** it SHALL preserve controller binding, draft settings construction, validation hints, connection test behavior, toast/snackbar feedback, auth mode picker, TLS toggle, and root path normalization

#### Scenario: WebDAV connection page uses clear grouped hierarchy

- **WHEN** `_WebDavConnectionScreen` renders the WebDAV server connection form
- **THEN** it SHALL group visible controls under “基础设置”, “认证设置”, “高级设置”, and “安全” or their localized equivalents
- **AND** the page title SHALL remain “服务器连接” or its localized equivalent with the existing back navigation behavior
- **AND** section labels, helper copy, row values, dividers, backgrounds, and action colors SHALL come from existing theme/settings/platform seams rather than a new color system or new hard-coded hex values

#### Scenario: WebDAV basic fields remain editable and understandable

- **WHEN** `_WebDavConnectionScreen` renders server URL, username, and password fields
- **THEN** server URL SHALL show example guidance equivalent to `https://example.com/dav`
- **AND** server URL SHALL expose a visible text action equivalent to “测试” that reuses the existing connection test logic
- **AND** username SHALL show placeholder guidance equivalent to “请输入用户名”
- **AND** password SHALL show placeholder guidance equivalent to “请输入密码”
- **AND** password visibility toggle SHALL keep the existing show/hide state behavior and use theme or icon-theme colors

#### Scenario: WebDAV auth mode copy is user-facing

- **WHEN** `_WebDavConnectionScreen` displays `WebDavAuthMode.basic`
- **THEN** the visible row value SHALL be “基础认证” or its localized equivalent
- **AND** the stored enum value, picker selection, provider write path, and WebDAV auth behavior SHALL remain unchanged

#### Scenario: WebDAV advanced and security settings explain risk and purpose

- **WHEN** `_WebDavConnectionScreen` renders root path and TLS certificate handling settings
- **THEN** root path SHALL be grouped under advanced settings and SHALL include helper copy equivalent to “用于指定 WebDAV 同步目录”
- **AND** root path SHALL preserve the existing default value, controller binding, provider write path, and normalization behavior
- **AND** `ignoreTlsErrors` SHALL be displayed as “允许不安全证书” or its localized equivalent
- **AND** the security row SHALL include helper copy equivalent to “仅建议在可信内网或测试环境中开启”
- **AND** the toggle SHALL preserve the existing `ignoreTlsErrors` default, state binding, and save behavior

#### Scenario: WebDAV connection save action has no network side effects

- **WHEN** the user taps the bottom primary action labeled “保存设置” or its localized equivalent
- **THEN** the page SHALL complete saving/form-finalization behavior by reusing existing setting write and normalization paths
- **AND** it SHALL NOT call the connection test logic
- **AND** it SHALL NOT start WebDAV sync, WebDAV backup, restore, Vault setup, or any new network operation
- **AND** it SHALL NOT automatically change WebDAV enabled, backup enabled, or auto-sync allowed state

#### Scenario: WebDAV backup settings page is migrated

- **WHEN** `_WebDavBackupSettingsScreen` renders backup content, config scope, backup mode, backup password/Vault entry, schedule, retention, unavailable hints, backup error copy, or exit guard
- **THEN** it SHALL use settings semantic page/section/row/action seams
- **AND** it SHALL preserve backup config/content writes, full config encryption guard, encryption mode picker, password setup flow, schedule picker, retention writes, backup password missing exit guard, and backup error presentation

#### Scenario: WebDAV logs page is migrated

- **WHEN** `WebDavLogsScreen` renders loading, empty state, log entries, refresh action, or log detail dialog
- **THEN** it SHALL avoid direct palette/local card styling and use settings/theme/platform seams
- **AND** it SHALL preserve log store reads, refresh behavior, entry ordering, and detail dialog content

#### Scenario: Drift guardrail reflects completed WebDAV migration

- **WHEN** this batch is implemented
- **THEN** `webdav_sync_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** it SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`
