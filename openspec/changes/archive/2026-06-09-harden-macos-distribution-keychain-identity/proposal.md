## Why

当前 macOS DMG 已能使用 `Developer ID Application` 签名并通过 notarization，但用户安装后遇到多次系统登录密码提示。已确认弹窗来自 macOS Keychain：`MemoFlow` 想访问钥匙串中的 `flutter_secure_storage_service` 项。根因不是 Gatekeeper，也不是 DMG 未公证，而是正式版、开发版、临时构建或旧签名构建可能共用了同一个 `Bundle ID` 和默认 `flutter_secure_storage` service，导致 Keychain 访问控制把新签名身份视为新的访问者。

本 change 先把长期整改规则写清楚：正式分发身份必须固定，开发/测试身份必须隔离，生产 Keychain service 不得被本地临时构建污染，打包流程必须验证最终 DMG 内 app 的身份和签名状态。实现阶段再按这些规则调整 runtime storage options、构建参数和打包校验。用户已确认这是第一版，暂不迁移旧 `flutter_secure_storage_service` 数据。

当前架构阶段是 `evolve_modularity`。本变更主要触及发布治理、macOS secure storage seam 和打包校验，不应扩大 `state -> features`、`application -> features`、`core -> higher-layer` 依赖。实现时如果触碰 shared secure storage provider，应把渠道判断收敛到稳定 helper 或 composition seam，而不是分散到业务页面。

## What Changes

- 建立 macOS 分发身份治理规则：
  - 正式版 SHALL 使用生产 `Bundle ID` `com.memoflow.hzc073`、生产 `Keychain service` `com.memoflow.hzc073.secure.production` 和正式签名身份。
  - 开发版 SHALL 使用 `com.memoflow.hzc073.dev` 与 `com.memoflow.hzc073.secure.dev`；测试版 SHALL 使用 `com.memoflow.hzc073.qa` 与 `com.memoflow.hzc073.secure.qa`。
  - ad-hoc build SHALL 使用非生产 `Bundle ID` 和非生产 `Keychain service`。
  - 生产 `Keychain service` SHALL NOT 被本地 debug、profile、ad-hoc 或未公证测试构建读取或写入。
- 将 `flutter_secure_storage` macOS 默认 service 从隐式 `flutter_secure_storage_service` 改为显式、按渠道区分的 service name。
- 第一版不迁移旧 Keychain 数据：生产版 SHALL NOT 主动读取旧 `flutter_secure_storage_service`；如未来需要迁移，必须另行确认并更新规则。
- 为 DMG/Developer ID 分发建立验收规则：最终 DMG 内 app 必须是稳定生产身份、`Developer ID` 签名、notarized、无 `get-task-allow`，且 `spctl` 接受。
- 保持公开仓库商业中立：不得把 Team ID、证书、notarization 凭据、App Store Connect 凭据、StoreKit、订阅、收据或价格逻辑写进公开 runtime。

## Capabilities

### New Capabilities

- `macos-distribution-identity-governance`: 定义 macOS 正式分发、开发/测试构建、Keychain service 隔离、旧 service 暂不迁移策略和 DMG/Developer ID 验收规则。

### Modified Capabilities

- `macos-app-store-release-readiness`: 后续实现应与既有 App Store/TestFlight 发布准备规则兼容，但本 change 不改变 App Store-only 的商业边界。
- `public-apple-branding`: 后续实现如调整生产 `Bundle ID`，应保持公开品牌 `MemoFlow` 不变。

## Impact

- Affected code, if implemented later:
  - `memos_flutter_app/lib/state/system/session_provider.dart`
  - `memos_flutter_app/lib/data/repositories/queued_secure_storage.dart`
  - focused tests under `memos_flutter_app/test/state/system` 或 `memos_flutter_app/test/data/repositories`
  - macOS build/signing or DMG packaging scripts if a script is added or updated
  - architecture/guardrail tests if they are used to enforce channel and commercial boundary rules
- API impact: 不修改 Memos server API request/response models、route adapters、version compatibility logic，且不得触碰 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`，除非用户另行明确批准。
- Data impact: 第一版不迁移旧 `flutter_secure_storage_service` 数据；用户可能需要重新登录或重新配置保存在旧 service 中的内容。后续如要迁移旧数据，应另开任务或更新本 change，并接受首次读取旧 service 可能触发旧钥匙串授权的成本。
- Distribution impact: DMG 签名和公证流程可以继续使用现有 `Developer ID` 路径，但必须增加生产 channel 参数和最终产物校验。
- Commercial/public boundary: 不引入 subscription、billing、entitlement、paywall、StoreKit、receipt、product ID、price、private overlay runtime 或发布凭据。
