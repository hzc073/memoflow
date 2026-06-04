## 1. 复现与保护测试

- [ ] 1.1 在 `memos_flutter_app/test/features/settings/desktop_settings_window_app_test.dart` 增加测试：settings 子窗口 local library key 集合变化时，`desktop.main.reloadWorkspace` payload 在可获得 session key 时包含 `currentKey`。
- [ ] 1.2 在 `memos_flutter_app/test/features/home/main_home_page_test.dart` 增加测试：`session.currentKey` 非空但本地库暂时匹配不到时，不渲染 `LanguageSelectionScreen` / 模式选择页。
- [ ] 1.3 为 `LocalLibrariesController` 增加 focused test：previous libraries 非空且 repository 返回 `StorageReadResult.empty()` 时，不会被一次 empty read 清空。
- [ ] 1.4 如实现调整 session empty-read 语义，补充 `AppSessionNotifier` focused test：previous session 有 `currentKey` 时，临时 empty read 不会清空 active key。

## 2. 桌面设置窗口 workspace IPC

- [ ] 2.1 更新 `DesktopSettingsWindowApp` 的 `localLibrariesProvider` listener：发送 `reason:'local_libraries'` reload 时读取当前 `session.currentKey`，非空则随 payload 传给主窗口。
- [ ] 2.2 确认 `DesktopWindowManager` 对带 `currentKey` 的 `desktop.main.reloadWorkspace` 继续先 reload session、再对齐 key、再 reload local libraries。
- [ ] 2.3 确认不带 `currentKey` 的 reload 不会单独清空主窗口 active session key，也不会单独触发 onboarding 跳转。

## 3. Workspace state reload 与 route gate

- [ ] 3.1 更新 `LocalLibrariesController._loadFromStorage`：previous state 非空且 read result 为 `empty` 时保留旧状态或进入可恢复 pending 状态，并记录诊断日志。
- [ ] 3.2 评估并按需要更新 `AppSessionNotifier._loadFromStorage`：previous session 有 active workspace 时，对可疑 empty read 采用同类保守语义。
- [ ] 3.3 更新 `MainHomePage` route gate：当 `session.currentKey` 非空但 local library match 暂时缺失时，保持 startup/locked home/pending 状态，不直接显示 onboarding。
- [ ] 3.4 保持 workspace 判定通过现有 provider / app bootstrap adapter / desktop channel seams 完成，不新增 `state -> features`、`application -> features` 或 `core -> features` 依赖。

## 4. 验证

- [ ] 4.1 从 `memos_flutter_app` 运行 focused tests：`flutter test test/features/settings/desktop_settings_window_app_test.dart test/features/home/main_home_page_test.dart`，并补跑新增 provider test 文件。
- [ ] 4.2 从 `memos_flutter_app` 运行 `flutter analyze`。
- [ ] 4.3 从 `memos_flutter_app` 运行 `flutter test`。
- [ ] 4.4 检查变更 diff，确认未触碰 API compatibility 文件、WebDAV 协议、数据库 schema、private hooks 或任何 subscription/billing/entitlement/paywall/StoreKit 逻辑。
