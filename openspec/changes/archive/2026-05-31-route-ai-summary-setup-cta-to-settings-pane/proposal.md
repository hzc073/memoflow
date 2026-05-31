## Why

`AI 总结` 页面在没有配置 AI 模型时会显示“AI 还没有配置”提示卡，并提供 `去设置` 按钮。当前按钮直接 push `AiSettingsScreen` 普通 route，导致 macOS / 桌面端从侧边栏或顶部快捷胶囊进入 `AI 总结` 后，再点击 `去设置` 时会绕过桌面设置窗口外壳，进入和 Windows / 桌面设置窗口不一致的设置表面。

已有 `DesktopSettingsWindowTarget.ai` seam 可以表达“打开设置窗口并选中 AI pane”。本 change 将这个 seam 接到 `AI 总结` 未配置 CTA，修正用户实际反馈的入口不一致问题。

## What Changes

- 将 `AiSummaryScreen` 中未配置提示卡的 `去设置` 路径改为优先打开目标化桌面设置窗口的 AI pane。
- 在桌面设置窗口 unsupported / failed 时保留 `AiSettingsScreen` fallback，确保移动端、Web 或失败场景仍有可见设置界面。
- 保留 `AI 总结` 页面、模板卡片、AI 设置表单和服务详情页内容不变。
- 增加 focused test，覆盖桌面端 CTA 请求 settings window AI target，以及 unsupported fallback 仍 push `AiSettingsScreen`。

## Capabilities

### Added Capabilities

- `ai-summary-settings-routing`: 定义 `AI 总结` 未配置 CTA 的目标化设置路由行为。

## Impact

- Affected app files: `memos_flutter_app/lib/features/review/ai_summary_screen.dart`
- Affected tests: `memos_flutter_app/test/features/review/ai_summary_screen_test.dart`
- Boundary: 使用现有 `DesktopSettingsWindowTarget.ai` seam，不修改 AI provider、repository、API、数据库 schema 或商业/private overlay 行为。
