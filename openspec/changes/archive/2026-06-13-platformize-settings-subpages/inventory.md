# Settings Subpage Migration Inventory

## 状态说明

- `migrated`: 已迁移到 settings/platform seam，并有 focused 或 smoke 覆盖。
- `in_progress`: 本 change 已触碰并完成高风险控件替换，但仍保留后续批次要迁移的低风险 Material fallback 或复杂 transient UI。
- `pending`: 已识别风险，等待后续 batch。
- `deferred`: 明确延期，通常因为页面体量较大或需要单独拆分。
- `exception`: 暂时保留 raw Material surface，需说明原因并在 guardrail allowlist 中记录。

## 已确认的 core seam

- `SettingsOptionChoiceRow`
- `SettingsOptionChipGroup`
- `SettingsSingleChoiceList` / `SettingsSingleChoiceRow`
- `SettingsMultiChoiceList` / `SettingsMultiChoiceRow`
- `showSettingsSingleChoicePicker`
- `SettingsAction` / `PlatformPrimaryAction`
- `showSettingsConfirmationDialog`
- `SettingsFeedbackRow`
- `SettingsProgressRow`

## Batch A

### migrated

- `memos_flutter_app/lib/features/settings/location_settings_screen.dart`
  - precision selection 已从 raw `ChoiceChip` 迁移到 `SettingsOptionChoiceRow`。
  - iOS focused test 覆盖页面打开和 precision 交互。
- `memos_flutter_app/lib/features/settings/bottom_navigation_mode_settings_screen.dart`
  - slot destination picker 已从 raw `showDialog` + `RadioGroup` + `RadioListTile` 迁移到 `showSettingsSingleChoicePicker`。
  - 保留 unavailable destination hidden 和 duplicate destination disabled 语义。
- `memos_flutter_app/lib/features/settings/customize_home_shortcuts_screen.dart`
  - quick entry picker 已从 raw `showDialog` + `RadioGroup` + `RadioListTile` 迁移到 `showSettingsSingleChoicePicker`。
  - 保留 signed-in candidate visibility 和 duplicate quick action disabled 语义。

### in_progress

- `memos_flutter_app/lib/features/settings/components_settings_screen.dart`
  - reminder permission confirmation 已迁移到 `showSettingsConfirmationDialog`。
  - feature navigation routes 已迁移到 `buildPlatformPageRoute`。
  - third-party share acknowledgement 已从 `CheckboxListTile` 迁移到 `SettingsMultiChoiceRow`。
  - 仍保留 `ThirdPartyShareCopyrightDialog` 的 Material `AlertDialog` fallback；后续 guardrail 可将该 dialog surface 作为 documented exception 或继续抽到更通用的 settings dialog seam。

## Batch B

### migrated

- `memos_flutter_app/lib/features/settings/memo_toolbar_settings_screen.dart`
  - custom toolbar button editor 已从 raw `showDialog` 迁移到 `showPlatformDialog`。
  - icon group selection 已从 raw `ChoiceChip` 迁移到 `SettingsOptionChipGroup`，并保留 `memo-toolbar-icon-group-*` 与 icon grid `ValueKey`。
  - editor form fields/actions 已迁移到 `SettingsFormDialog`、`SettingsDialogTextField`、`SettingsDialogAction`。
  - iOS focused test 覆盖 custom editor 打开、icon group 切换、保存 custom button。
- `memos_flutter_app/lib/features/settings/shortcut_editor_screen.dart`
  - tag picker 已从 raw `showModalBottomSheet` 迁移到 `showPlatformPicker`。
  - selected tag chips 已从 `InputChip` 迁移到 `SettingsRemovableChip`。
  - tag multi-select 已从 `CheckboxListTile` 迁移到 `SettingsMultiChoiceList`。
  - iOS focused test 覆盖 tag picker 打开、选择 tag、返回 editor。
- `memos_flutter_app/lib/features/settings/template_settings_screen.dart`
  - template editor、variable settings、variable docs 已从 raw `showDialog` / `AlertDialog` 迁移到 `showPlatformDialog` + `SettingsFormDialog`。
  - template delete confirmation 已迁移到 `showSettingsConfirmationDialog`。
  - dialog form fields/actions 已迁移到 `SettingsDialogTextField`、`SettingsDialogAction`。
  - iOS focused test 覆盖 docs dialog 和 variable settings dialog。

## Batch C

### migrated

- `memos_flutter_app/lib/features/settings/ai_route_settings_screen.dart`
  - route picker 已从 raw bottom sheet / adaptive surface helper 迁移到 `showSettingsSingleChoicePicker<AiSelectableRouteOption>`。
  - 保留 `replaceTaskRouteBindings`、model capability filtering 和 default route binding 语义。
- `memos_flutter_app/lib/features/settings/ai_service_wizard_screen.dart`
  - provider template dialog 已迁移到 `showPlatformDialog` + `SettingsFormDialog`。
  - service/model form fields 已迁移到 `SettingsDialogTextField`，model capability selection 已迁移到 `SettingsMultiChoiceList`。
  - preset `ActionChip`、shared proxy / default model `SwitchListTile` 和 proxy route 已迁移到 `SettingsActionPill`、`SettingsToggleRow`、`buildPlatformPageRoute`。
  - iOS smoke test 覆盖 service form seam 且验证无 raw `ActionChip`、`FilterChip`、`SwitchListTile`、`TextFormField`。
- `memos_flutter_app/lib/features/settings/ai_service_model_screen.dart`
  - model editor dialog 已迁移到 `showPlatformDialog<AiModelEntry>` + `SettingsFormDialog`。
  - source/sort popup filters 已迁移到 `showSettingsSingleChoicePicker`；model capability selection 已迁移到 `SettingsMultiChoiceList`。
  - model list actions 和 preset add action 已迁移到 `SettingsAction` / icon actions，移除 `PopupMenuButton`。
  - iOS smoke test 覆盖 model editor seam 且验证无 raw chip/form/dialog controls。
- `memos_flutter_app/lib/features/settings/ai_service_detail_screen.dart`
  - service detail fields、enabled/shared proxy toggles、docs/check/save actions 已迁移到 settings/platform seams。
  - unsaved close prompt 已迁移到 `showPlatformAlertDialog`，delete confirmation 已迁移到 `showSettingsConfirmationDialog`。
  - proxy settings nested route 已迁移到 `buildPlatformPageRoute`，保留 connection check、save、delete 和 nested route semantics。
- `memos_flutter_app/lib/features/settings/ai_provider_settings_screen.dart`
  - legacy provider model picker/custom model dialog 已迁移到 `showPlatformDialog` + `SettingsFormDialog`。
  - generation/embedding fields 已迁移到 `SettingsDialogTextField`，save error feedback 迁移到 `showTopToast`。
  - 保留 generation URL validation、model option add/delete/select 和 legacy settings persistence 语义。
  - iOS smoke test 覆盖 legacy provider form seam 且验证无 raw `TextFormField`、`AlertDialog`、`SwitchListTile`。

## Batch D

### migrated

- `memos_flutter_app/lib/features/settings/webdav_sync_screen.dart`
  - WebDAV auth mode、backup schedule、backup encryption mode、config scope、snapshot/restore/conflict/vault actions 已迁移到 `showSettingsSingleChoicePicker`、`showSettingsConfirmationDialog`、`showPlatformDialog`、`SettingsFormDialog`、`SettingsSingleChoiceList`、`SettingsMultiChoiceRow`。
  - password/recovery/config restore forms 已迁移到 `SettingsDialogTextField` 和 settings dialog actions。
  - backup/sync progress、inline loading 与 primary actions 已迁移到 `PlatformProgress`、`SettingsAction`、`PlatformPrimaryAction`。
  - 保留 WebDAV auth、schedule、encryption、backup/restore、vault、sync provider/service 调用语义，不修改 protocol、archive format 或 service behavior。
- `memos_flutter_app/lib/features/settings/vault_security_status_screen.dart`
  - cleanup confirmations、password/recovery dialogs、backup test picker 已迁移到 settings/platform seams。
  - load/verify/test feedback 已迁移到 `showTopToast`，loading indicator 已迁移到 `PlatformProgress`。
  - 保留 vault status load、remote cleanup、backup verification/test semantics。
- `memos_flutter_app/lib/features/settings/account_security_screen.dart`
  - local scan conflict/confirm、remove local library、remove account confirmation 已迁移到 `showSettingsConfirmationDialog`。
  - scan/cache result feedback 已迁移到 `showTopToast`，保留 local library scan、remove 和 account cache cleanup semantics。
- `memos_flutter_app/lib/features/settings/storage_space_screen.dart`
  - clear cache confirmation 已迁移到 `showSettingsConfirmationDialog`。
  - cache result feedback 已迁移到 `showTopToast`，summary/category loading 已迁移到 `PlatformProgress`。
- `memos_flutter_app/lib/features/settings/self_repair_screen.dart`
  - repair confirmation 已迁移到 `showSettingsConfirmationDialog`。
  - repair result feedback 已迁移到 `showTopToast`，row loading indicator 已迁移到 `PlatformProgress`。

### coverage

- `settings_ui_drift_guardrail_test.dart` 增加 Batch D seam/forbidden-control guardrail，覆盖 WebDAV、Vault、Account、Storage、Self Repair 目标文件。
- `webdav_conflict_flow_test.dart` 增加 iOS conflict dialog smoke，验证 WebDAV conflict dialog 使用 `SettingsFormDialog`、`SettingsMultiChoiceRow`、`SettingsSingleChoiceList`，且无 raw `AlertDialog` / `CheckboxListTile` / `RadioListTile`。
- `settings_screen_test.dart` 覆盖 account security、vault security status、storage entry 仍通过 settings semantic rows 打开。
- `utility_settings_pages_test.dart` 和 `self_repair_media_cache_test.dart` 覆盖 Self Repair / Storage cache focused flows。
- `PlatformPrimaryAction` iOS icon+label content 支持有界宽度下收缩，避免 migrated action seam 在长文案下触发 RenderFlex overflow。

## Batch E

### migrated

- `memos_flutter_app/lib/features/settings/migration/memoflow_migration_sender_screen.dart`
  - sender package route/result route 已迁移到 `buildPlatformPageRoute`。
  - content/config selection 已从 `CheckboxListTile` 迁移到 `SettingsMultiChoiceRow`。
  - package building progress 已迁移到 `SettingsProgressRow`。
  - 保留 local library mode、include memos/settings、safe/sensitive config defaults 和 package build semantics。
- `memos_flutter_app/lib/features/settings/migration/memoflow_migration_receiver_screen.dart`
  - receive mode 已从 `SegmentedButton` 迁移到 `SettingsSingleChoiceList`。
  - sensitive config confirmation 已从 `CheckboxListTile` 迁移到 `SettingsMultiChoiceRow`。
  - receiving progress/result route 已迁移到 `SettingsProgressRow` 和 `buildPlatformPageRoute`。
  - 保留 QR/session/proposal review、receive mode、accepted sensitive config 和 result semantics。
- `memos_flutter_app/lib/features/settings/migration/memoflow_migration_role_screen.dart`
  - sender/receiver navigation 已迁移到 `buildPlatformPageRoute`。
- `memos_flutter_app/lib/features/settings/migration/memoflow_migration_send_method_screen.dart`
  - QR scanner/result routes 已迁移到 `buildPlatformPageRoute`。
  - manual receiver entry 已从 raw Material dialog/form field 迁移到 `showPlatformDialog` + `SettingsFormDialog` + `SettingsDialogTextField`。
  - upload/wait/build progress 已迁移到 `SettingsProgressRow`。
  - 保留 QR scan auto-connect、manual host/port/pair-code validation、nearby receiver 和 send result semantics。
- `memos_flutter_app/lib/features/settings/local_network_migration_screen.dart`
  - MemoFlow migration 与 Obsidian bridge routes 已迁移到 `buildPlatformPageRoute`。
- `memos_flutter_app/lib/features/settings/import_export_screen.dart`
  - Batch E scan 确认无 remaining raw high-risk controls，继续作为 settings navigation hub。
- `memos_flutter_app/lib/features/settings/support_memoflow_screen.dart`
  - open/copy feedback 已从 `ScaffoldMessenger` / `SnackBar` 迁移到 `showTopToast`。
- `memos_flutter_app/lib/features/settings/user_general_settings_screen.dart`
  - save feedback 已迁移到 `showTopToast`，loading state 已迁移到 `SettingsProgressRow`。
  - API read/write semantics 未修改。
- `memos_flutter_app/lib/features/settings/export_memos_screen.dart`
  - export completion dialog 已迁移到 `showPlatformAlertDialog`。
  - export action loading indicator 已迁移到 `PlatformProgress`，feedback 已迁移到 `showTopToast`。
- `memos_flutter_app/lib/features/settings/export_logs_screen.dart`
  - clear logs confirmation 已迁移到 `showSettingsConfirmationDialog`。
  - notes input 已迁移到 `PlatformTextField`，copy path action 已迁移到 icon action，feedback 已迁移到 `showTopToast`。
- `memos_flutter_app/lib/features/settings/api_plugins_screen.dart`
  - expiration picker 已迁移到 `showSettingsSingleChoicePicker`。
  - token name field 已迁移到 `SettingsDialogTextField`，created-token sheet 已迁移到 `showPlatformDialog` + `SettingsFormDialog`。
  - create loading/retry controls 已迁移到 platform/settings seams，token API semantics 未修改。
- `memos_flutter_app/lib/features/settings/webhooks_settings_screen.dart`
  - add/edit webhook editor 已迁移到 `showPlatformDialog` + `SettingsFormDialog` + `SettingsDialogTextField`。
  - delete confirmation/loading/retry/feedback 已迁移到 settings/platform seams。
  - create/update/delete API semantics 未修改。
- `memos_flutter_app/lib/features/settings/password_lock_screen.dart`
  - password dialog 已迁移到 `showPlatformDialog` + `SettingsFormDialog` + `SettingsDialogTextField`。
  - auto-lock picker 已迁移到 `showSettingsSingleChoicePicker`，validation feedback 已迁移到 `SettingsFeedbackRow`。
- `memos_flutter_app/lib/features/settings/desktop_shortcuts_settings_screen.dart`
  - restore defaults action 与 shortcut capture dialog 已迁移到 settings/platform seams。
  - capture validation feedback 已迁移到 `SettingsFeedbackRow`，keyboard capture semantics 未修改。

### coverage

- `settings_ui_drift_guardrail_test.dart` 增加 Batch E seam/forbidden-control guardrail。
- Focused tests 覆盖 migration sender/send-method、local network migration、export memos、export logs、API plugins、webhooks。
- iOS smoke tests 覆盖 API token field、webhooks editor form、password lock password dialog。

## 当前边界

- 本 change 不触碰 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`。
- 本 change 不修改 WebDAV protocol、database schema、sync protocol、backup archive format 或 migration data format。
- 本 change 不加入 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching。
