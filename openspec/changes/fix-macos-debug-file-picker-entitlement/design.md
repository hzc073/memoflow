## Context

现有 `Release.entitlements` 已包含 `com.apple.security.files.user-selected.read-write`，符合公开附件选择能力。`DebugProfile.entitlements` 缺少同一权限，导致 `flutter run -d macos --flavor Runner` 生成的 Debug-Runner 只带 sandbox/JIT/network 权限，文件选择器在本地调试时可能无法正常显示或使用。

## Decision

在 `memos_flutter_app/macos/Runner/DebugProfile.entitlements` 中增加：

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

该文件同时用于 Debug 和 Profile 配置，因此一次修改覆盖本地 debug/profile 运行路径。Release 配置保持不变。

## Alternatives

- 只在代码层捕获 `FilePicker.platform.pickFiles()` 异常并提示用户：不能解决 native panel 无法打开的根因。
- 改用其他文件选择 plugin：当前 `file_picker` 已接入并注册，问题不在插件缺失；替换依赖会扩大风险。
- 关闭 macOS app sandbox：不符合 release readiness 和 macOS 安全边界。

## Risks

- 修改 entitlements 后需要重建 macOS app，正在运行的旧 Debug-Runner 不会自动获得新签名权限。
- 如果仍无法打开文件选择器，下一步应继续检查 native panel 与窗口激活状态，而不是扩大权限范围。

## Modularity

Architecture phase: `evolve_modularity`。本变更只调整 macOS Runner 签名配置，不触碰 Dart 分层、feature 页面、state provider 或 application seam，因此不会引入新的 reverse dependency。公开/私有商业边界保持不变。
