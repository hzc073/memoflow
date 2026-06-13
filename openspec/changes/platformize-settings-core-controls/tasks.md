## 1. Settings/platform 控件 seam

- [x] 1.1 梳理 `settings_ui.dart`、`platform_controls.dart`、`platform_primary_action.dart`、`platform_dialog.dart` 现有能力，确认需要新增或扩展的控件 API。
- [x] 1.2 新增或扩展 settings semantic choice seam，覆盖 chip-like choice、single-choice、multi-choice，并保持 caller 传入 label/value/options/onChanged。
- [x] 1.3 让 Apple mobile choice/multi-choice 控件在 `SettingsPage` + `SettingsSection` 内不依赖 `Material` ancestor。
- [x] 1.4 保持 Material/desktop 分支视觉和现有交互尽量稳定，避免影响非 Apple mobile 设置页。

## 2. Actions、dialogs、feedback 与 progress

- [x] 2.1 扩展 `PlatformPrimaryAction` / `SettingsAction`，让 iPhone/iPadOS 分支使用 Cupertino-safe action presentation。
- [x] 2.2 明确 destructive/default/secondary action variant 的平台映射，并保留桌面 bounded/aligned 行为。
- [x] 2.3 提供 settings/platform confirmation dialog 和 lightweight feedback 使用建议或 helper，避免 Apple mobile 依赖偶然 `ScaffoldMessenger`。
- [x] 2.4 确认 loading/progress 控件有 platform-safe seam，可用于设置页空态、加载态和长任务状态。

## 3. 边界与结构保护

- [x] 3.1 确认新增或修改的 `platform/` 控件不导入 `features/*`、`state/*`、`application/*` 或 `data/*`。
- [x] 3.2 确认 settings-owned 控件不直接读取业务 provider，不拥有 repository/API/database/WebDAV 行为。
- [x] 3.3 确认本 change 不引入 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching。

## 4. 测试

- [x] 4.1 为 settings choice/single-choice/multi-choice 控件增加 `TargetPlatform.iOS` widget tests，断言无 `No Material widget found`。
- [x] 4.2 为 settings actions/dialog/feedback/progress 的 Apple mobile 分支增加 focused tests 或覆盖到现有 semantic component tests。
- [x] 4.3 运行 focused settings/platform control tests。
- [x] 4.4 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 4.5 按需要运行 `flutter test`。（本次运行 focused settings/platform widget tests，未跑全量 `flutter test`。）

## 5. Diff 检查

- [x] 5.1 检查 diff，确认未触碰 API compatibility 文件、WebDAV 协议、数据库 schema、private hooks 或任何商业/paid-feature 逻辑。
- [x] 5.2 检查 OpenSpec delta 与任务描述，确认第二个 change `platformize-settings-subpages` 可以复用本 change 提供的控件 seam。
