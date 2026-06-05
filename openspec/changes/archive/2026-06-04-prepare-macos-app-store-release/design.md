## Context

当前 macOS 工程已经能构建 release app，但现有 Apple 平台身份仍是 `com.memoflow.memosFlutterApp`，更像 Flutter 脚手架标识；Android 当前正式 `applicationId` 是 `com.memoflow.hzc073`。用户已决定 macOS 也改为与 Android 一致，并通过 Apple 官方渠道下载和更新，不在 GitHub 发布安装包。

本设计只处理 Apple 商店发布前置准备，不实现 StoreKit/IAP 业务。当前架构阶段为 `evolve_modularity`，本变更不应触碰既有 `state -> features`、`application -> features`、`core -> higher-layer` 依赖热点；如果实现阶段增加扫描或 guardrail，只能收紧公开/私有边界。

## Goals / Non-Goals

**Goals:**

- 将 macOS Bundle ID 固定为 `com.memoflow.hzc073`，与 Android 当前 `applicationId` 对齐。
- 保持 App 名 `MemoFlow` 和公开版本号与其他平台对齐。
- 将发布渠道限定为 TestFlight / Mac App Store，不把 GitHub release、DMG、notarization 站外分发作为当前发布路径。
- 明确 Apple 签名、App Store Connect、权限声明和隐私说明的实现边界。
- 保护公开仓库：不引入 StoreKit、IAP、订阅、收据、产品 ID、价格、个人 Team ID、签名密钥或发布自动化。

**Non-Goals:**

- 不实现订阅、买断、试用、价格、收据校验或 StoreKit 交易处理。
- 不创建 GitHub 安装包发布流程。
- 不实现站外 DMG 分发、Developer ID notarization、Sparkle 自动更新或下载页。
- 不在用户尚未确认权限清单前提交最终 entitlements/privacy 文案。
- 不更改 Android `applicationId` 或现有用户安装身份。

## Decisions

1. **Bundle ID 与 Android 对齐**

   使用 `com.memoflow.hzc073` 作为 Apple 平台正式 Bundle ID。备选方案是使用 `com.hzc073.memoflow` 或 `com.memoflow.app`，但前者会与 Android 现有身份不一致，后者会形成第三个产品身份。与 Android 对齐更利于跨平台识别和长期维护。

2. **商店路径优先，不生成 DMG**

   当前发布目标是 Apple 管理下载、测试和更新，因此实现阶段应面向 App Store Connect/TestFlight 准备。DMG 是站外分发交付物，和“从商店下载即可”的目标冲突；如未来需要站外分发，应另开变更处理 Developer ID、notarization、stapling 和下载页。

3. **签名配置可以存在，机密不得存在**

   Xcode 工程可以具备 App Store 构建所需的非机密配置结构，例如 Bundle ID、Release entitlements 和 hardened runtime 相关设置。但个人开发者 Team ID、证书、App Store Connect API key、app-specific password、provisioning profile、notarization credential 和 CI secret 不应提交到公开仓库。实现阶段如需要本地签名，应使用本机 Xcode 设置、未跟踪 local xcconfig、私有 overlay 或 CI secret。

4. **权限声明采用首版最小公开功能集**

   用户已确认首版 macOS 按实际公开功能申请权限：保留 `App Sandbox`、`Network Client`、`Network Server`、`User Selected Files Read/Write`、麦克风、定位、本地网络/Bonjour，以及 Keychain self-use。通知、相机、照片库、辅助功能/输入监控、屏幕录制、通讯录、日历、蓝牙、USB、Apple Events 等没有当前 macOS 功能路径或会扩大审核解释面的能力不进入首版声明。权限文案必须说明用户可见用途，不能暗示未实现功能。

5. **商业化继续走 private hooks seam**

   商业化方向是“全部走 Apple”，但公开 shell 仍不能直接包含 StoreKit/IAP/订阅逻辑。后续私有 overlay 可以通过 `private_hooks` 提供升级入口、权益映射和设置贡献；公开设置页只渲染贡献项，不判断商业状态。

6. **公开 macOS shell 与私有商业发布基础设施分离**

   公开仓库可以保留非商业 `memos_flutter_app/macos` shell，因为它是社区构建和 Apple 平台公开品牌的一部分。发布自动化、签名密钥、商业 runtime 和 StoreKit 实现仍属于私有仓库或本地/CI 机密配置。

## Risks / Trade-offs

- [Risk] 个人开发者账号会暴露实名 seller name。→ Mitigation: 发布前在任务清单中保留人工确认项；如不能接受，先切换公司/组织账号再上架。
- [Risk] 提交过宽权限会导致 App Review 问题或降低用户信任。→ Mitigation: 只声明当前 macOS 公开功能实际使用的权限；通知、相机、照片库、辅助功能/输入监控等未启用能力不写入 `Info.plist` 或 Release entitlements。
- [Risk] 将 Apple Team ID 或签名配置写入公开仓库会泄露个人主体信息。→ Mitigation: 公开仓库只保留 Bundle ID 等非机密身份；签名账户信息通过本地或私有配置注入。
- [Risk] 后续 StoreKit 代码误进公共 shell。→ Mitigation: 收紧 `memos_flutter_app/test/architecture/*` guardrail，继续禁止 StoreKit、receipt、subscription、product ID、price 等商业词和实现进入公共 shell。
- [Risk] 与旧 `private-macos-overlay-boundary` 中“macOS 平台脚手架由私有仓库拥有”的描述冲突。→ Mitigation: 本变更显式替换该旧要求，改为公开 shell 可存在但必须商业中立。

## Migration Plan

1. 按已确认权限清单更新 macOS `Info.plist` 和 Release entitlements。
2. 将 `PRODUCT_BUNDLE_IDENTIFIER` 从 `com.memoflow.memosFlutterApp` 改为 `com.memoflow.hzc073`。
3. 确认 `CFBundleShortVersionString` 和 `CFBundleVersion` 继续从 Flutter `pubspec.yaml` 的公开版本读取。
4. 调整或记录 App Store 构建配置，但不提交个人 Team ID、证书或密钥。
5. 运行 macOS build、architecture guardrails、`flutter analyze` 和相关 tests。
6. 使用 Xcode/App Store Connect 在本地或私有发布环境完成 TestFlight 上传验证。

## Open Questions

- 首次 TestFlight 是否直接使用当前公开版本 `1.0.32+32`，还是保留版本号但用新的 build number？
- 是否接受个人 seller name 公开展示，还是在正式上架前切换组织账号？
