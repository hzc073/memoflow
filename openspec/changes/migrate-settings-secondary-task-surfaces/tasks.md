## 1. 准备和边界确认

- [x] 1.1 确认本 change 不修改 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`；如果实现中发现 API 相关修改必要，暂停并请求用户明确批准。
- [x] 1.2 复查 `PlatformSecondaryTaskSurface`、Collections presenter 模式和现有 desktop secondary task guardrail，确认复用方式。
- [x] 1.3 复查 `generalize-desktop-settings-platform-sections` 的范围，避免同时修改桌面设置入口命名、pane 分段或 settings UI drift allowlist。

## 2. 快捷方式编辑任务表面

- [x] 2.1 为 `ShortcutEditorScreen` 新增统一打开入口，例如 `openShortcutEditor(...)`，桌面端使用共享任务表面，移动端保留 route。
- [x] 2.2 让 `ShortcutEditorScreen` 支持嵌入 `PlatformSecondaryTaskFrame`，桌面端显示明确标题、关闭/取消和完成操作。
- [x] 2.3 更新 `ShortcutsSettingsScreen` 的创建/编辑入口，改用统一打开入口并保留 `ShortcutEditorResult` 保存流程。
- [x] 2.4 更新 `MemosListRouteDelegate.createShortcutFromMenu`，改用统一打开入口并保留创建后刷新和选中新 shortcut 的行为。
- [x] 2.5 增加或更新 focused widget tests，覆盖桌面端使用任务表面、移动端保持 route、完成结果仍正确传回调用方。

## 3. AI 服务新增向导任务表面

- [x] 3.1 为 `AiServiceWizardScreen` 新增统一打开入口，例如 `openAiServiceWizard(...)`，桌面端使用共享任务表面，移动端保留 route。
- [x] 3.2 让 `AiServiceWizardScreen` 支持嵌入 `PlatformSecondaryTaskFrame`，桌面端显示明确标题和关闭/取消入口。
- [x] 3.3 更新 `AiSettingsScreen` 的添加服务入口，改用统一打开入口。
- [x] 3.4 保持 AI 向导内 `AiProxySettingsScreen` 的打开方式不变，并在测试或实现备注中记录它不是本 change 的迁移范围。
- [x] 3.5 增加或更新 focused widget tests，覆盖桌面端添加服务使用任务表面、移动端保持原行为、代理设置入口仍可打开。

## 4. 防回退检查

- [x] 4.1 增加或更新 architecture guardrail，确认已迁移入口使用 `openShortcutEditor(...)` / `openAiServiceWizard(...)`，不再直接 push 对应页面。
- [x] 4.2 确认已迁移 settings 任务页面不手写 `kMacosTrafficLightReservedWidth` 或页面级 macOS traffic-light padding。
- [x] 4.3 确认新增 presenter/helper 不引入 `state -> features`、`application -> features` 或 `core -> features` 反向依赖。

## 5. 验证

- [x] 5.1 运行 focused settings / memos route delegate widget tests。
- [x] 5.2 运行相关 architecture guardrail tests。
- [x] 5.3 运行 `flutter analyze`。
- [x] 5.4 运行 `openspec validate migrate-settings-secondary-task-surfaces --strict`。
- [ ] 5.5 在桌面端手动验证快捷方式编辑和 AI 服务新增向导：标题、关闭/取消、完成结果、代理设置入口和移动端导航行为都符合预期。
