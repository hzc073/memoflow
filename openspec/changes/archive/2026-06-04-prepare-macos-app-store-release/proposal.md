## Why

macOS 版本准备改为通过 Apple 官方渠道发布，首要风险不在功能实现，而在发布身份、签名/权限配置、商业边界和公开仓库内容是否提前定稳。现在需要把 App Store/TestFlight 发布前置事项纳入 OpenSpec，避免用临时 Flutter 工程标识进入正式 Apple 平台发布链路。

当前架构阶段是 `evolve_modularity`。本变更主要触及 Apple 平台外壳、公开/私有边界和发布配置 guardrail，不触及既有 `state -> features`、`application -> features`、`core -> higher-layer` 热点实现；如实现阶段修改守护测试，应确保边界不扩大并让公开仓库扫描更严格。

## What Changes

- 将 macOS 发布路径明确为 Apple 官方渠道：优先 TestFlight 验证，再通过 Mac App Store 发布；公开 GitHub 不发布安装包。
- 将 Apple 平台正式 Bundle ID 规划为与 Android 当前 `applicationId` 对齐的 `com.memoflow.hzc073`，不再使用 Flutter 工程感较强的 `com.memoflow.memosFlutterApp`。
- 保持用户可见 App 名 `MemoFlow` 和公开版本号与其他平台对齐；当前公开版本基线为 `1.0.32+32`。
- 明确个人 Apple Developer 主体可用于发布，但 seller name/合规展示风险需要在发布清单中显式确认。
- 将 macOS 首版权限/能力声明固定为最小公开功能集：Sandbox、Network Client、Network Server、User Selected Files Read/Write、Microphone、Location、Local Network/Bonjour，以及 Keychain self-use；不申请通知、相机、照片库、辅助功能/输入监控等未启用能力。
- 保持商业化全部走 Apple 的方向，但 StoreKit、IAP、订阅、收据、权益、价格、产品 ID 和发布凭据仍不得进入公开 shell。
- 去掉 DMG 作为商店发布路径的交付目标；DMG 仅在未来站外分发变更中另行讨论。

## Capabilities

### New Capabilities
- `macos-app-store-release-readiness`: 覆盖 macOS App Store/TestFlight 发布前置身份、版本、权限、签名配置边界、交付路径和公开仓库发布约束。

### Modified Capabilities
- `public-apple-branding`: 将 Apple 平台公开应用身份扩展到正式 Bundle ID，对齐 Android 当前 `applicationId`。
- `private-macos-overlay-boundary`: 调整公开 macOS shell 的边界描述，允许公开仓库保留非商业 macOS 平台壳，同时继续禁止商业实现、发布密钥和自动化泄漏。

## Impact

- 可能影响 `memos_flutter_app/macos/Runner/Configs/AppInfo.xcconfig` 中的 `PRODUCT_BUNDLE_IDENTIFIER`。
- 可能影响 `memos_flutter_app/macos/Runner.xcodeproj/project.pbxproj` 中的 Apple Team、签名、hardened runtime 或 App Store 发行配置，但不得提交个人证书、密钥、App Store Connect API key、notarization 密码或其他机密。
- 可能影响 macOS `Info.plist`、entitlements、privacy/permission 描述和 App Store Connect 元数据准备清单。
- 可能新增或收紧 `memos_flutter_app/test/architecture/*` 下的 Apple 发布/商业边界 guardrail。
- 不应引入 StoreKit/IAP 运行时代码；后续商业功能必须继续通过私有 overlay 和 `private_hooks` seam 进入。
