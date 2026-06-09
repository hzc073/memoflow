## Context

已观察到 macOS 弹窗文案为：

```text
MemoFlow 想要使用你储存在钥匙串中的
"flutter_secure_storage_service" 中的机密信息。
```

这说明问题发生在 Keychain 访问控制层。当前 app 启动会通过 `secureStorageProvider` 访问 `flutter_secure_storage`，macOS 默认 `accountName` 为 `flutter_secure_storage_service`。如果历史上同一个 service 被 ad-hoc、本地 release、旧 `Bundle ID` 或不同签名身份写入，正式 `Developer ID` 版本再次读取时，Keychain 会按 item 询问用户是否允许新 app 访问，因此会出现多次密码提示。

DMG 本身已验证为 `Developer ID Application: zhoucai han (M38GS93L5A)`，`spctl` 显示 `accepted` 和 `Notarized Developer ID`。因此整改重点不是“让 DMG 通过 Gatekeeper”，而是“让不同渠道不共享同一 Keychain service，并让生产构建身份稳定”。

## Goals / Non-Goals

**Goals:**

- 将生产版 macOS 身份固定为一组稳定的 `Bundle ID`、`Developer ID` 和生产 `Keychain service`。
- 让开发版、临时测试版和 ad-hoc build 使用独立身份与独立 `Keychain service`，避免污染生产 Keychain item。
- 让 macOS secure storage options 可由明确渠道决定，而不是依赖默认 `flutter_secure_storage_service`。
- 第一版不主动读取或迁移旧默认 service，避免为了迁移再次触发旧钥匙串授权。
- 给 DMG 分发增加验收规则，确保最终 app 身份、签名、公证和 entitlements 符合预期。

**Non-Goals:**

- 不在本 change 中实现 StoreKit、订阅、买断、收据校验、价格、产品 ID 或商业权益逻辑。
- 不提交 Apple Team ID 以外的签名秘密，不提交证书、notarization 密码、App Store Connect API key 或 provisioning profile。
- 不把 DMG 发布自动化变成公开仓库商业发布系统；可保留非机密校验脚本和文档规则。
- 不在第一版实现旧 `flutter_secure_storage_service` 数据迁移；如未来需要迁移，应另行确认迁移范围和用户提示。
- 不修改 Memos server API 兼容性代码。

## Decisions

### 1. 显式命名生产 Keychain service

生产版 SHALL 使用显式 service name `com.memoflow.hzc073.secure.production`。该命名已经确认，必须满足：

- 不再使用隐式默认 `flutter_secure_storage_service` 作为长期生产 service。
- 不与开发、测试、ad-hoc 构建共用。
- 一经发布，不随版本号、打包方式、DMG 文件名变化。

备选方案是继续使用默认 service，只通过用户点击“始终允许”解决。该方案短期可行，但不能阻止后续本地构建再次污染生产 Keychain，因此不作为长期治理规则。

### 2. 开发和测试构建独立身份

开发/测试构建 SHOULD 同时隔离 `Bundle ID` 和 `Keychain service`。已确认命名如下：

```text
生产版:
  Bundle ID:        com.memoflow.hzc073
  Keychain service: com.memoflow.hzc073.secure.production

开发版:
  Bundle ID:        com.memoflow.hzc073.dev
  Keychain service: com.memoflow.hzc073.secure.dev

临时测试版:
  Bundle ID:        com.memoflow.hzc073.qa
  Keychain service: com.memoflow.hzc073.secure.qa
```

只隔离 service 但不隔离 `Bundle ID` 可以降低 Keychain 冲突，但仍可能污染 macOS app container、TCC 隐私授权和用户对应用身份的认知。因此两者应一起隔离。

### 3. 生产 channel 必须由打包流程显式指定

DMG 打包流程 SHOULD 显式传入 production channel，例如通过 `--dart-define` 或等价构建配置。实现时应避免业务页面直接判断 channel；应由 composition root 或 secure storage provider seam 生成 `MacOsOptions(accountName: ...)`。

该规则的目标是让最终产物可验证：

```text
打包参数 -> app runtime channel -> Keychain service -> codesign/spctl 验收
```

### 4. 第一版不迁移旧 Keychain 数据

用户已确认这是第一版，暂时不用考虑旧钥匙串。生产版切换到 `com.memoflow.hzc073.secure.production` 后，第一版 SHALL NOT 主动读取旧 `flutter_secure_storage_service`，避免为了迁移再次触发旧钥匙串密码提示。

该选择的结果是：

- 旧 service 中保存的账号、token 或部分设置不会自动带到第一版新 service。
- 用户可能需要重新登录或重新配置相关 secure settings。
- 后续如果要迁移旧 service，必须先更新 OpenSpec 并明确是否读取、复制、删除或保留旧项。

### 5. DMG 验收关注最终挂载内容

签名验收 SHALL 检查 DMG 内的 `MemoFlow.app`，而不是只检查 build 目录或 zip。原因是打包脚本可能对 app 做重新签名、重打包、notarize 和 staple。验收命令应覆盖：

- `codesign -dv --verbose=4`
- `codesign -d --entitlements :-`
- `codesign --verify --deep --strict --verbose=4`
- `spctl -a -vvv -t exec`
- DMG notarization/staple 状态

### 6. 公开仓库只保留非机密规则和校验

公开仓库可以包含 channel 选择规则、非机密 service name、签名验收脚本和 guardrail，但不得包含证书、密码、notarization 凭据、App Store Connect API key、私有商业 runtime 或 StoreKit 逻辑。

## Risks / Trade-offs

- [Risk] 不迁移旧 service 会让用户丢失账号、token 或部分设置。→ Mitigation: 用户已确认这是第一版，可以暂时不考虑旧钥匙；实现和发布说明应接受重新登录或重新配置成本。
- [Risk] 未来如果再加旧 service 迁移，首次读取旧项可能重新触发 Keychain 授权。→ Mitigation: 未来迁移必须另行确认，并清楚标注首次迁移成本。
- [Risk] 多渠道配置散落到业务代码。→ Mitigation: channel 到 secure storage options 的映射应集中在 provider/helper，不进入 screen/widget。
- [Risk] 将签名身份写入公开仓库泄露个人主体。→ Mitigation: 可校验 `Developer ID` 存在和 `spctl accepted`，但敏感凭据和私有发布自动化不进入公开仓库。
- [Risk] DMG 站外分发与既有 App Store 优先设计冲突。→ Mitigation: 本 change 只定义 DMG/Developer ID 身份治理和校验，不改变 App Store/TestFlight 作为官方渠道的既有规则；若要正式支持站外分发，应在实现任务中保持边界清晰。

## Confirmed Decisions

- 生产 `Bundle ID`: `com.memoflow.hzc073`
- 生产 `Keychain service`: `com.memoflow.hzc073.secure.production`
- 开发 `Bundle ID`: `com.memoflow.hzc073.dev`
- 开发 `Keychain service`: `com.memoflow.hzc073.secure.dev`
- 测试 `Bundle ID`: `com.memoflow.hzc073.qa`
- 测试 `Keychain service`: `com.memoflow.hzc073.secure.qa`
- 第一版旧 service 策略：不读取、不迁移 `flutter_secure_storage_service`
