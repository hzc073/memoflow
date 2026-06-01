## 1. System hotkey 注册状态

- [x] 1.1 在 `DesktopQuickInputController` 或等价 application-owned seam 中新增 `quickRecord` system hotkey 注册状态，覆盖 unavailable/registered/failed 或等价语义
- [x] 1.2 在 `registerHotKey(DevicePreferences prefs)` 开始、注册成功、注册失败、binding 缺失或平台不支持时更新状态，避免保留过期成功状态
- [x] 1.3 在 `unregisterHotKey()` 中同步清理注册状态，确保 full exit 或重新注册后不会误判为 active

## 2. 主窗口快捷键 fallback 分发

- [x] 2.1 扩展 `MemosListDesktopShortcutDelegate` 的输入，将 `quickRecord` delegated 判断从 `traySupported()` 调整为 system hotkey active 语义
- [x] 2.2 当 system hotkey inactive 且 route active 时，`quickRecord` SHALL 调用 `onOpenQuickRecord()` 并返回 matched fallback dispatch
- [x] 2.3 在 `MemosListScreen` 或 composition seam 中接入 application-owned 注册状态，不让 feature delegate 直接调用 `hotKeyManager` 或解析注册异常
- [x] 2.4 保留 route inactive、app lock、inline editor 和无状态栏/托盘支持时的既有行为边界

## 3. 测试与模块边界

- [x] 3.1 更新 `memos_list_desktop_shortcut_delegate_test.dart`，覆盖 system hotkey registered 时 delegated、failed/inactive 时 in-window fallback、route inactive 时不 fallback
- [x] 3.2 增加或更新 `DesktopQuickInputController` 相关 focused tests，验证注册成功、注册失败、binding 缺失和 unregister 后的状态变化
- [x] 3.3 检查 touched imports，确认未新增 `application -> features`、`state -> features` 或 `core -> higher layer` 依赖；必要时补充现有 architecture guardrail 覆盖
- [x] 3.4 确认本 change 未引入 subscription、billing、entitlement、StoreKit、paywall、private overlay 或 `AccessDecision.source` business branching

## 4. 验证

- [x] 4.1 在 `memos_flutter_app` 运行 focused tests：快捷键 delegate、desktop quick input controller、相关 architecture guardrails
- [x] 4.2 在 `memos_flutter_app` 运行 `flutter analyze`
- [ ] 4.3 如可用，在 Windows 或 macOS 手动 smoke：模拟/触发 system hotkey 注册失败后，主窗口内快捷键可以打开快速记录；注册成功时后台热键仍可打开快速记录
