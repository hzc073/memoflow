## Context

用户反馈的实际入口是主窗口 `AI 总结` 页面中的未配置提示卡，而不是 macOS 顶部菜单 `AI > AI Settings`。该提示卡由 `AiSummaryScreen` 渲染，按钮回调 `_openAiSettings()` 直接执行：

```text
Navigator.push(MaterialPageRoute(builder: (_) => const AiSettingsScreen()))
```

因此这条路径绕过了桌面设置窗口和 `_DesktopSettingsPane.ai`。

## Decisions

### 1. CTA 优先请求桌面设置窗口 AI pane

桌面平台上，`_openAiSettings()` 应调用：

```text
openDesktopSettingsWindow(target: DesktopSettingsWindowTarget.ai)
```

如果返回 opened，则不再 push fallback route。这样从侧边栏或顶部快捷胶囊进入 `AI 总结` 后，点击 `去设置` 会进入与桌面设置窗口一致的 AI 设置 pane。

### 2. fallback 仍由当前 UI 入口负责

`openDesktopSettingsWindow(...)` 已能报告 unsupported / failed。`AiSummaryScreen` 保留 `AiSettingsScreen` fallback，覆盖移动端、Web、插件不可用或目标窗口失败场景。

### 3. 不扩大到其他 AI 设置入口

`ai_insight_settings_sheet.dart` 里也有 `Open AI Settings` 按钮，但本次用户截图和入口指向的是 `AiSummaryScreen` 顶部未配置提示卡。为避免扩大范围，本 change 先只修正该入口；后续可单独扫描其他 AI 设置 CTA。

## Risks / Trade-offs

- [Risk] 桌面窗口 target 发送失败后用户看不到设置。Mitigation: 保留 fallback push。
- [Risk] widget test 中真实 `desktop_multi_window` plugin 不可用。Mitigation: 使用 method channel mock 覆盖 target payload。
- [Trade-off] `AiSummaryScreen` 会直接依赖 desktop settings window seam。该 seam 属于 application 层稳定目标路由，不引入 `application -> features` 反向依赖，也不把设置页面构造下移。
