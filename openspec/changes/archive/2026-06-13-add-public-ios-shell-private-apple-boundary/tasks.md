## 1. 规则与文档更新

- [x] 1.1 更新 `docs/private-extension-boundary.md`，把 “Apple platform scaffolding is absent from the public repository” 改写为公开 Apple 基础壳可存在、Apple 商业运行时和发布秘密必须私有。
- [x] 1.2 更新 `docs/private-overlay-workflow.md`，将 macOS-only 私有仓语义升级为 Apple private overlay，覆盖 macOS、iPhone、iPadOS。
- [x] 1.3 更新 `docs/private-bundle-template.md`，说明 iOS / iPadOS 商业权益也通过 `active_private_extension_bundle.dart` 和 `AppCapability` 映射进入公开代码。
- [x] 1.4 检查 OpenSpec specs 与 docs 的命名一致性，确保不会再要求整个 Apple platform scaffolding 只能由私有仓拥有。

## 2. 公开 iOS Runner

- [x] 2.1 在 `memos_flutter_app` 中生成或恢复 `ios/` 基础 Runner，并审查生成 diff，删除无关 scaffold churn。
- [x] 2.2 配置 iOS public display name 为 `MemoFlow`。
- [x] 2.3 配置 iOS public bundle identifier 为 `com.memoflow.hzc073`，且不提交 Team ID、provisioning profile、certificate、signing secret 或 App Store Connect credential。
- [x] 2.4 确认 iOS Runner 使用公开 `lib/main.dart` 或批准的公开 entrypoint，不依赖私有仓路径或 private package。
- [x] 2.5 确认 `pubspec.yaml`、asset、splash、icon 和 iOS project metadata 只包含公开基础壳需要的改动。

## 3. iOS 权限与基础功能范围

- [x] 3.1 参考 Android `full` 版本权限，列出 iOS public shell 首轮需要声明的基础能力：network、camera、photo/media、microphone、location、local network、notification、share handling。
- [x] 3.2 为 `ios/Runner/Info.plist` 中每个 privacy key 写入用户可理解的公开功能用途说明。
- [x] 3.3 确认 `Info.plist` usage description 不提及 paid support、subscription、entitlement、StoreKit、Apple supporter、private commercial features 或 future-only capability。
- [x] 3.4 不为 iCloud、App Groups、Shortcuts/App Intents、Spotlight、StoreKit、receipt validation 或其他未批准 Apple ecosystem capability 提前添加 entitlement。

## 4. Public / Private 边界实现

- [x] 4.1 确认 `memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart` 在公开仓继续保持 no-op public bundle。
- [x] 4.2 确认公开 `settings`、`support`、`home`、`platform`、`app.dart`、`main.dart` 不根据 `TargetPlatform.iOS` 或 `TargetPlatform.macOS` 直接显示购买、恢复购买、价格或权益 UI。
- [x] 4.3 确认任何未来 private Apple supporter UI 只通过 `SettingsEntryContribution`、support page contribution、route intent 或等价批准 seam 进入公开 UI。
- [x] 4.4 确认公开代码只消费 product-level `AppCapability`，不读取 raw `free`、`trial`、`subscriptionPro`、`buyoutPro`、receipt、transaction、price、product ID 或 `AccessDecision.source` 做业务判断。

## 5. Modularity 与 guardrails

- [x] 5.1 为 iOS public shell 增加 `memos_flutter_app/test/architecture/ios_public_shell_guardrail_test.dart` 或等价 guardrail，检查 identity、permission posture、commercial-free terms、signing/release secret absence。
- [x] 5.2 收紧 `.github/scripts/public_repo_guardrails.ps1`，覆盖 `memos_flutter_app/ios/` 中的 StoreKit、IAP、product ID、price、receipt、entitlement implementation、signing secret、TestFlight 和 App Store Connect 自动化泄漏。
- [x] 5.3 增加或扩展 architecture guardrail，确认 iOS 接入未引入新的 `platform -> features/state/application/data` 依赖，且没有新的 `state -> features`、`application -> features` 或 `core -> higher-layer` 依赖。
- [x] 5.4 如果后续实现需要改 `main.dart` 或 `app.dart`，提取或使用 runtime/bootstrap seam 收束 iOS/mobile 初始化，避免继续扩大 composition root 平台分支。
- [x] 5.5 检查 public shell restricted files，确认没有新增 subscription、billing、entitlement、paywall、StoreKit、price、product ID、paid-feature state 或 private repository import。

## 6. Verification

- [x] 6.1 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 6.2 从 `memos_flutter_app` 运行 focused architecture/private hook guardrail tests，包括新增 iOS public shell guardrail。
- [x] 6.3 在可用 Xcode 环境中运行 `flutter build ios --no-codesign` 或等价 iOS public shell smoke。已运行 `flutter build ios --no-codesign --config-only`；完整 device/simulator build 在本机因 Xcode destination 报 `iOS 26.5 is not installed` 被阻塞。
- [x] 6.4 从 `memos_flutter_app` 运行 `flutter test`；如耗时或环境阻塞，记录阻塞原因和已运行的 focused tests。已运行，当前有 4 个非本次 iOS shell 变更范围内的失败：`test/private_hooks/app_ready_hook_test.dart`、`test/features/home/home_bottom_nav_shell_test.dart` 两例、`test/features/onboarding/platform_adaptive_onboarding_test.dart` 一例。
- [x] 6.5 运行或人工复核 public repo guardrail，确认公开仓未引入 StoreKit、商品、价格、收据、权益、签名秘密或 Apple 发布自动化。
- [x] 6.6 检查最终 diff，确认未触碰 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、数据库 schema、WebDAV 协议或无关商业/private overlay 实现。
