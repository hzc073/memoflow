## 1. 前置与清单

- [x] 1.1 确认 `platformize-settings-core-controls` 已提供 choice、single-choice、multi-choice、action、dialog、feedback、progress 等可复用 seam。
- [x] 1.2 创建或更新 settings subpage migration inventory，标记 migrated、pending、deferred、exception 文件。
- [x] 1.3 明确本 change 不触碰 API compatibility、WebDAV protocol、database schema、private hooks 或商业/paid-feature 逻辑。

## 2. Batch A：已知崩溃和简单选择

- [x] 2.1 迁移 `LocationSettingsScreen` precision selection，移除 `ChoiceChip` 直接嵌入 Apple grouped-list content 的风险。
- [x] 2.2 迁移 `bottom_navigation_mode_settings_screen.dart` 和 `customize_home_shortcuts_screen.dart` 中的 raw `RadioListTile` dialog 为 platform/settings choice seam。
- [x] 2.3 迁移 `components_settings_screen.dart` 中高风险 `CheckboxListTile` 或确认 dialog。
- [x] 2.4 增加 iOS focused tests 覆盖上述页面可打开、可交互且无 `No Material widget found`。

## 3. Batch B：Toolbar、Shortcut、Template

- [x] 3.1 迁移 `MemoToolbarSettingsScreen` custom button dialog 中的 icon group choice 和 raw actions/fields。
- [x] 3.2 迁移 `ShortcutEditorScreen` 中的 `InputChip`、`CheckboxListTile`、raw bottom sheet/action controls。
- [x] 3.3 迁移 `TemplateSettingsScreen` 中 raw dialogs、text fields 和 actions 到 settings/platform seams。
- [x] 3.4 保留 toolbar drag/drop、shortcut filter、template variable semantics 和 existing `ValueKey`s。
- [x] 3.5 增加 focused tests 或 iOS smoke tests。

## 4. Batch C：AI 设置页面

- [x] 4.1 迁移 `AiServiceWizardScreen` 中 `ActionChip`、`FilterChip`、`SwitchListTile`、raw text fields/dialogs/routes。
- [x] 4.2 迁移 `AiServiceModelScreen` 中 `FilterChip`、popup filters、raw form controls/dialogs。
- [x] 4.3 迁移 `AiServiceDetailScreen` 和 `AiProviderSettingsScreen` 中 raw form controls/actions/dialogs。
- [x] 4.4 保留 AI provider/model/route persistence、validation、default route semantics。
- [x] 4.5 增加 AI 设置 focused tests 或 iOS smoke tests。

## 5. Batch D：WebDAV、Vault、Account、Storage、Self Repair

- [x] 5.1 分阶段迁移 `WebDavSyncScreen` 中 dropdown、radio、checkbox、dialogs、buttons、progress/feedback 到 settings/platform seams。
- [x] 5.2 迁移 `VaultSecurityStatusScreen`、`AccountSecurityScreen`、`StorageSpaceScreen`、`SelfRepairScreen` 中 raw dialogs/actions/feedback。
- [x] 5.3 保留 WebDAV auth、schedule、encryption、backup/restore、vault、sync semantics，不修改 protocol/service behavior。
- [x] 5.4 增加 WebDAV/Vault/Account/Storage/SelfRepair focused tests 或 iOS smoke tests。

## 6. Batch E：Migration 与剩余设置页

- [x] 6.1 迁移 MemoFlow migration sender/receiver/method/result screens 中 `SegmentedButton`、`CheckboxListTile`、progress、routes、actions。
- [x] 6.2 迁移 user/general/support/export/import/local network 等剩余设置页中的 raw high-risk controls。
- [x] 6.3 保留 migration sender/receiver/proposal/QR/progress/data-transfer semantics。
- [x] 6.4 增加 migration/remaining pages focused tests 或 iOS smoke tests。

## 7. Guardrails 与验证

- [x] 7.1 更新 settings UI drift guardrail 或 allowlist，把完成迁移的文件移入 migrated list。
- [x] 7.2 Guardrail 覆盖 migrated files 中的 `ChoiceChip`、`FilterChip`、`ActionChip`、`InputChip`、`DropdownButton`、`RadioListTile`、`CheckboxListTile`、raw `MaterialPageRoute`、raw Material dialog/sheet APIs。
- [x] 7.3 从 `memos_flutter_app` 运行 focused settings subpage tests。
- [x] 7.4 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 7.5 按需要运行 `flutter test`。

## 8. Diff 检查

- [x] 8.1 检查 diff，确认未触碰 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、WebDAV protocol、database schema、private hooks。
- [x] 8.2 检查 diff，确认未加入 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching。
- [x] 8.3 更新 OpenSpec inventory/notes，记录完成、延期和例外项。
