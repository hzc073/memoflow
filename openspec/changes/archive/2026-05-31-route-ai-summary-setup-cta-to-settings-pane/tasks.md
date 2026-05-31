## 1. 路径确认

- [x] 1.1 确认用户截图对应 `AiSummaryScreen` 未配置提示卡的 `去设置` CTA。
- [x] 1.2 确认当前 `_openAiSettings()` 直接 push `AiSettingsScreen`，不是桌面设置窗口 target。

## 2. 实现

- [x] 2.1 将 `AiSummaryScreen._openAiSettings()` 改为优先请求 `DesktopSettingsWindowTarget.ai`。
- [x] 2.2 保留 unsupported / failed 时的 `AiSettingsScreen` fallback。
- [x] 2.3 不修改 AI provider、repository、API、数据库 schema、服务详情表单或商业/private overlay 行为。

## 3. Tests

- [x] 3.1 增加 focused test，覆盖桌面端点击 `去设置` 发送 AI settings target，且成功时不 push fallback。
- [x] 3.2 增加 focused test，覆盖 unsupported 平台点击 `去设置` 会 push `AiSettingsScreen` fallback。

## 4. 验证

- [x] 4.1 运行 `flutter test test/features/review/ai_summary_screen_test.dart --reporter expanded`。
- [x] 4.2 运行相关 architecture guardrail tests 或确认本 change 不需要新增架构 guardrail。
- [x] 4.3 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 4.4 运行 `openspec validate route-ai-summary-setup-cta-to-settings-pane --strict`。
