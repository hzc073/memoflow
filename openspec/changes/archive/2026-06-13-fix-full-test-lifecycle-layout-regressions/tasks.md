## 1. 规则与范围

- [x] 1.1 新增 `desktop-quick-record-hotkey-fallback` delta spec，约束 app teardown hotkey release 不得写 disposed provider。
- [x] 1.2 新增 `home-navigation-back-safety` delta spec，约束 shell-launched About route 内容必须可滚动且保持 shell/back 语义。
- [x] 1.3 确认本 change 不触碰 API route/version compatibility、request/response model 或 `memos_flutter_app/lib/data/api` / `memos_flutter_app/test/data/api`。

## 2. Hotkey dispose 生命周期修复

- [x] 2.1 在 `DesktopQuickInputController` 中提供 teardown-safe hotkey release path，正常 unregister 仍更新 provider 状态。
- [x] 2.2 调整 `App.dispose` 使用 teardown-safe release path，避免 disposed `WidgetRef` 被读取。
- [x] 2.3 补充或确认 focused controller/app ready tests 覆盖正常 unregister 与 app dispose 行为。

## 3. About destination layout 修复

- [x] 3.1 调整 `AboutScreen` 的 drawer/home destination body，为 `AboutUsContent` 提供 bounded scroll container。
- [x] 3.2 保持 `AboutUsScreen` / `AboutUsContent` 在 settings page 内的现有 semantic settings seam 与内容断言。
- [x] 3.3 确认 shell-launched about back 与 standalone about fallback 测试不再触发 overflow，且仍返回 bottom navigation shell。

## 4. 验证

- [x] 4.1 在 `memos_flutter_app` 运行 `flutter test test/private_hooks/app_ready_hook_test.dart --reporter expanded`。
- [x] 4.2 在 `memos_flutter_app` 运行 `flutter test test/application/desktop/desktop_quick_input_controller_test.dart --reporter expanded`。
- [x] 4.3 在 `memos_flutter_app` 运行 `flutter test test/features/home/home_bottom_nav_shell_test.dart --reporter expanded`。
- [x] 4.4 在 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 4.5 在 `memos_flutter_app` 运行 `flutter test --reporter expanded` 或记录剩余 blocker。
- [x] 4.6 提交前检查 staged/unstaged changes，确认没有商业、订阅、计费、entitlement、paywall、StoreKit 或其他 paid-feature code 泄漏到 public repository。
