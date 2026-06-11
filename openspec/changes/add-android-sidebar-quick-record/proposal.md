## Why

GitHub issue #209 请求适配 Android 厂商侧边栏、文件中转站、选中文本等快速入口，让用户可以把外部文本或媒体拖入 MemoFlow 后直接进入记录流程。现有普通第三方分享已经支持部分 `ACTION_SEND` 场景，但缺少面向“快速记录”的入口语义：选中文本入口未注册，`ClipData` 文本可能被忽略，且 URL 会被普通分享逻辑自动带入 QuickClip/剪藏。

## What Changes

- 新增 Android 快速记录入口模式，用于侧边栏、选中文本、拖拽类来源。
- 支持快速记录入口接收纯文本、图片、视频等媒体 URI，并打开现有输入框让用户确认发送。
- 快速记录入口中的 URL MUST 按普通文本处理，不触发 QuickClip/剪藏。
- 普通第三方分享入口保持现有行为：URL 继续可走 QuickClip/剪藏，避免回归已有分享体验。
- 快速记录入口复用现有 `thirdPartyShareEnabled` 偏好和工作区可用性判断。
- 不引入自动保存；用户仍需在输入框内确认提交。

## Capabilities

### New Capabilities

- `android-sidebar-quick-record`: 覆盖 Android 侧边栏、选中文本、拖拽快速记录入口的接收、分流和打开输入框行为。

### Modified Capabilities

- 无。

## Impact

- 预计影响 `memos_flutter_app/android/app/src/main/AndroidManifest.xml` 和 `memos_flutter_app/android/app/src/main/kotlin/com/memoflow/hzc073/MainActivity.kt`，用于注册并解析 Android 快速记录入口。
- 预计影响 `memos_flutter_app/lib/features/share/share_handler.dart` 及分享启动协调相关测试，用于表达快速记录入口模式并绕过 URL 剪藏。
- 如需绕过 QuickClip，可能触碰 `memos_flutter_app/lib/application/startup/startup_coordinator_share.dart`。当前项目处于 `evolve_modularity` 阶段，且该区域属于既有 `application -> features` 耦合热点；实现 MUST 通过 scoped seam 或 guardrail 保证触碰区域不变差。
- 不修改 Memos server API、`memos_flutter_app/lib/data/api/**` 或 `memos_flutter_app/test/data/api/**`。
- 不新增订阅、付费、权益、StoreKit 或其他商业逻辑。
