## Why

MemoFlow 需要把 iPhone / iOS 作为公开基础平台纳入仓库，让公开仓在没有私有商业代码时也能构建和验证基础 iPhone 体验。与此同时，后续会存在付费后才可用的 Apple 权益，因此必须把 iOS 公共壳、权限、品牌身份和 Apple 私有商业 overlay 的边界先写清楚，避免 StoreKit、商品、价格、收据或权益判断泄漏进公开仓。

## What Changes

- 在公开仓规则中允许新增 `memos_flutter_app/ios/` 基础 Runner，使 iPhone 版基础功能可独立构建、运行和测试。
- 固化公开 iOS App 身份：显示名称为 `MemoFlow`，Bundle ID 为 `com.memoflow.hzc073`。
- 定义公开 iOS 首版权限策略：参考 Android `full` 版本的基础能力范围，但每个 iOS permission / `Info.plist` usage description 都必须对应公开功能，不得为未来私有商业能力提前声明。
- 将私有仓库语义从 “macOS private overlay” 升级为 “Apple private overlay”，覆盖 macOS、iPhone、iPadOS 的商业运行时、付费权益、StoreKit、购买/恢复购买、商品配置、价格、收据校验和 Apple 发布自动化。
- 保持公开仓只通过批准 seam 接收私有能力：`memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart` 仍是唯一 Dart overlay 入口，公开 UI 只渲染 contribution 或消费 product-level `AppCapability`，不得读取 raw entitlement / StoreKit / 商品 / 价格状态。
- 更新旧文档和规格中 “Apple/macOS 平台脚手架不在公开仓” 的表述，改为 “Apple public shell scaffolding may exist in public repo; Apple commercial runtime and release secrets stay private.”
- 为 iOS 公共壳增加或规划 guardrail，检查 `ios/`、public shell、shared models、platform seams、private hooks 是否保持商业无关、权限最小且不包含签名/发布秘密。

## Capabilities

### New Capabilities

- `ios-public-shell-boundary`: 约束公开 iOS Runner、iPhone App 身份、公开基础权限、public shell 可构建性，以及 iOS 公共壳不得包含 Apple 商业运行时或发布秘密。

### Modified Capabilities

- `private-macos-overlay-boundary`: 将旧的 macOS-only 私有 overlay 边界泛化为 Apple private overlay 边界，允许公开仓拥有 Apple public shell scaffolding，同时要求商业 runtime、StoreKit、权益和发布秘密保留在私有仓。
- `apple-commercialization-capability-boundary`: 明确 iOS / iPadOS 付费权益和 Apple 商业能力也必须通过 private overlay 映射为 product-level `AppCapability`，公开代码不得读取 raw commercial state。
- `public-apple-branding`: 扩展公开 Apple 品牌规则，使公开 iOS 壳使用 `MemoFlow` 和 `com.memoflow.hzc073`，并保持品牌元数据不携带商业或发布秘密。
- `phase-1-boundary-freeze`: 移除早期 “公开仓不得包含 macOS 平台脚手架” 的临时冻结口径，替换为 “公开 Apple 基础壳可存在，Apple 商业运行时和发布秘密必须私有”。

## Impact

- Affected public OpenSpec/docs:
  - `openspec/specs/private-macos-overlay-boundary/spec.md`
  - `openspec/specs/apple-commercialization-capability-boundary/spec.md`
  - `openspec/specs/public-apple-branding/spec.md`
  - `openspec/specs/phase-1-boundary-freeze/spec.md`
  - `docs/private-extension-boundary.md`
  - `docs/private-overlay-workflow.md`
  - `docs/private-bundle-template.md`
- Affected future public code:
  - `memos_flutter_app/ios/`
  - `memos_flutter_app/pubspec.yaml`
  - `memos_flutter_app/lib/main.dart`
  - `memos_flutter_app/lib/app.dart`
  - `memos_flutter_app/lib/platform/`
  - `memos_flutter_app/lib/private_hooks/`
  - `memos_flutter_app/test/architecture/ios_public_shell_guardrail_test.dart`
  - `.github/scripts/public_repo_guardrails.ps1`
- Affected future private code:
  - Apple private overlay repository, replacing the older macOS-only private framing.
  - Private StoreKit / entitlement / product configuration packages.
  - Private iOS/macOS signing, TestFlight, App Store Connect, and release automation.
- Architecture phase: `evolve_modularity`.
- Modularity checklist impact:
  - 触及 checklist `5`：后续 iOS 启动接入不得让 `main.dart` / `app.dart` 继续膨胀为平台分支堆叠，应优先通过 runtime/bootstrap seam 收束平台初始化。
  - 触及 checklist `6`：Apple 私有商业 UI 与公开 settings/home/support 表面必须通过 bundle/provider contribution seam 协作，而不是直接 import private feature。
  - 触及 checklist `8`、`10`：本 change 要求新增或收紧 guardrail，防止 iOS 公共壳、共享模型和 private hooks 边界退化。
