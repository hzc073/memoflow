## 1. 规则确认

- [x] 1.1 确认生产 `Bundle ID` 为 `com.memoflow.hzc073`。
- [x] 1.2 确认生产 `Keychain service` 为 `com.memoflow.hzc073.secure.production`。
- [x] 1.3 确认开发/测试命名规则：开发版使用 `com.memoflow.hzc073.dev` 与 `com.memoflow.hzc073.secure.dev`；测试版使用 `com.memoflow.hzc073.qa` 与 `com.memoflow.hzc073.secure.qa`。
- [x] 1.4 确认第一版不迁移旧 `flutter_secure_storage_service`，即不主动读取旧钥匙串；用户可重新登录或重新配置相关 secure settings。

## 2. Secure Storage Channel 设计

- [x] 2.1 设计 macOS secure storage channel helper 或 policy，将 production/dev/test channel 映射为对应 `MacOsOptions(accountName: ...)`。
- [x] 2.2 确认 helper 不导入 `features/*`、`application/*` 或 API code，避免扩大架构依赖。
- [x] 2.3 确保第一版 production channel 不读取旧 `flutter_secure_storage_service`。
- [x] 2.4 确保第一版在新生产 service 为空时保持可登录、可重新配置，不依赖旧 service 迁移。

## 3. 打包与验收规则

- [x] 3.1 规划 DMG 打包命令的 production channel 参数，例如 `--dart-define` 或等价配置。
- [x] 3.2 增加或更新非机密验收脚本，挂载最终 DMG 后检查内部 `MemoFlow.app`。
- [x] 3.3 验收脚本 SHALL 检查 `codesign` 不是 ad-hoc、存在 `Developer ID` authority、存在 `TeamIdentifier`、无 `get-task-allow`。
- [x] 3.4 验收脚本 SHALL 检查 `spctl` 显示 accepted，并确认 notarized/stapled 状态。
- [x] 3.5 验收脚本 SHALL 检查最终 `Bundle ID` 与 production channel 预期一致。

## 4. Guardrails and Tests

- [x] 4.1 为 secure storage channel helper 增加 focused unit tests，覆盖 production/dev/test service name。
- [x] 4.2 增加 focused tests，覆盖第一版 production channel 不读取旧 `flutter_secure_storage_service`，且新生产 service 为空时可进入重新登录或重新配置路径。
- [x] 4.3 增加或收紧架构 guardrail，防止生产 Keychain service 被 debug/ad-hoc channel 复用。
- [x] 4.4 增加或收紧公开仓库扫描，确保不引入证书、notarization credential、App Store Connect credential、StoreKit、订阅、收据、价格或产品 ID。
- [x] 4.5 运行相关 architecture guardrails，确认未新增 `state -> features`、`application -> features`、`core -> higher layer` 依赖。

## 5. Verification

- [x] 5.1 运行 focused tests for secure storage channel and first-release no-legacy behavior。
- [ ] 5.2 运行 macOS DMG 验收脚本，对最终 DMG 内 app 进行 `codesign`、entitlements、`spctl` 和 notarization 检查。
- [x] 5.3 运行 `flutter analyze`。
- [x] 5.4 运行相关 Flutter tests；如无法全量运行，记录具体阻断。
- [x] 5.5 运行 `openspec validate harden-macos-distribution-keychain-identity --strict`。
- [x] 5.6 复核本 change 未编辑 API compatibility 文件，未引入商业私有逻辑或发布凭据。
