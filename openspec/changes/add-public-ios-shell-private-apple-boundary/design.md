## Context

当前 `memos_flutter_app` 已经有 `android/`、`macos/`、`windows/`，但没有 `ios/`。Dart 层已经存在 `PlatformTarget.iPhone`、`PlatformTarget.iPad`、`PlatformRuntime.iOS`、`AppleMobileShell`、`AppleTabletShell` 和一批 `platform/` adaptive UI seam，因此 iPhone 支持不是从零开始做 UI，而是补齐公开 iOS 原生 Runner、权限、构建规则和 public/private 边界。

现有 public/private 分离依赖 `PrivateExtensionBundle`：

```text
public shell
├─ app.dart
├─ settings/support surfaces
├─ private_hooks/private_extension_bundle.dart
├─ private_hooks/private_extension_bundle_provider.dart
└─ private_hooks/active_private_extension_bundle.dart  public no-op
        ▲
        │ private overlay replacement
Apple private overlay
```

历史文档仍保留 “Apple platform scaffolding is absent from public repository” 和 `private-macos-overlay-boundary` 的 macOS-only 表述，但仓库已经有公开 `macos/` 和 macOS public shell guardrail。新增 `ios/` 前应先把治理规则改成 Apple-wide：公开仓可以拥有 Apple public shell scaffolding，Apple commercial runtime 和 release secrets 必须留在私有仓。

## Goals / Non-Goals

**Goals:**

- 允许公开仓新增 `memos_flutter_app/ios/`，并规定公开 iOS 壳在没有私有 overlay 时可构建基础 iPhone 版。
- 固化公开 iOS 身份：`MemoFlow` / `com.memoflow.hzc073`。
- 规定 iOS 权限参考 Android `full` 的基础能力范围，但必须逐项映射到公开功能和用户可读 usage description。
- 将私有仓库语义升级为 Apple private overlay，覆盖 macOS、iPhone、iPadOS 的 StoreKit、购买、恢复购买、权益、商品、价格、收据和发布自动化。
- 通过 spec/docs/guardrail 约束公开仓不得包含 Apple 商业实现细节。
- 在 `evolve_modularity` 阶段，要求后续实现用 runtime/bootstrap seam 或 guardrail 限制 `main.dart` / `app.dart` 继续堆积平台初始化分支。

**Non-Goals:**

- 本 change 不实现 `ios/` Runner、不运行 `flutter create --platforms=ios .`，也不修改应用代码。
- 不接入 StoreKit、不定义商品 ID、价格、订阅组、试用、买断策略或权益矩阵。
- 不决定 App Store Connect、TestFlight、证书、provisioning profile、Team ID 或 release workflow。
- 不改变 API、数据库 schema、WebDAV 协议、同步协议或 Memos server compatibility 逻辑。

## Decisions

### 1. 公开仓拥有 iOS public shell scaffolding

后续实现应在 `memos_flutter_app/ios/` 中生成并维护基础 iOS Runner。这个 Runner 属于公开基础平台支持，和公开 `macos/` 一样不代表公开仓拥有 Apple 商业版。

选择这个方案的原因：

- 公开仓可以独立验证 iPhone 基础体验，不依赖私有仓才能运行。
- `PlatformTarget.iPhone` / `iPad` 已经存在，公开 Runner 能让已有 platform adaptive UI 进入真实设备验证。
- 公开基础壳更容易加 guardrail，防止后续商业代码以“平台支持”的名义混入。

替代方案是继续让私有仓拥有整个 `ios/`。这个方案会让公开仓无法独立验证 iPhone 基础功能，也会把基础平台问题和商业发布问题绑在一起，因此不采用。

### 2. iOS 权限参考 Android `full`，但以公开功能用途为准

Android `full` 版本保留了更完整的媒体库权限；iOS 首版可以参考它覆盖基础附件、相机、录音、定位、本地网络、通知等能力。但 iOS 的权限声明必须以 `Info.plist` usage description 为准，每一项都应说明当前公开功能用途。

推荐首轮权限盘点：

```text
Android full capability        iOS public shell review
────────────────────────       ─────────────────────────────
Internet / network             public sync, API, WebDAV, web content
Camera                         photo attachment, QR / scanner if public
Record audio                   voice memo / audio attachment
Location                       attach current place to memo
Local network / multicast      local migration / nearby discovery
Notifications                  reminders / public notification features
Photo / media access           gallery attachment import, image picking
Share intents                  receive/share content if public iOS flow exists
```

不应因为未来 Apple private entitlement、StoreKit、iCloud、App Groups、Shortcuts 或 Spotlight 计划而提前声明权限或 entitlement。若某项 Apple ecosystem 能力属于付费权益，其商业判断仍在 private overlay 中完成；公开仓只可以拥有被批准的非商业平台配置。

### 3. Apple private overlay 替代 macOS-only private overlay

后续文档和规格应使用 Apple private overlay 表述，语义覆盖：

```text
Apple private overlay
├─ macOS commercial edition
├─ iPhone commercial edition
├─ iPadOS commercial edition
├─ StoreKit / IAP
├─ purchase / restore
├─ entitlement evaluation
├─ product IDs / prices
├─ receipt / transaction validation
└─ TestFlight / App Store release automation
```

公开仓仍只保留 `active_private_extension_bundle.dart` 这个 Dart overlay seam。若未来需要更多 Apple 原生 overlay seam，必须另开 OpenSpec 变更批准，不能在本 change 中默许。

### 4. 商业能力进入公开代码前必须先变成 product-level capability

公开 feature / state / application 代码不能读取 raw `free`、`trial`、`subscriptionPro`、`buyoutPro`、`expired`、`refunded`、product ID、price、transaction 或 receipt。私有仓负责把这些状态映射成 `AppCapability` 决策，公开代码只知道某个产品能力是否 enabled。

依赖方向应保持：

```text
public feature/state/application
        │
        ▼
appCapabilityEnabledProvider(AppCapability.x)
        │
        ▼
privateExtensionBundleProvider
        │
        ▼
PrivateExtensionBundle.diagnosticsAccessBoundary
        ▲
        │ private replacement
Apple private overlay
```

公开 settings/support surface 如果要展示购买、恢复购买或 supporter UI，只能渲染 private contribution，不能根据 `TargetPlatform.iOS` 或 `TargetPlatform.macOS` 自行显示商业 UI。

### 5. `main.dart` / `app.dart` 后续实现应顺手收束平台初始化

当前 `main.dart` 和 `app.dart` 已经承担大量 desktop runtime 初始化。新增 iOS 时如果继续直接塞平台分支，会加剧 checklist `5` 的问题。

后续实现应优先考虑：

- 把 iOS / mobile bootstrap 逻辑放进小型 runtime helper 或 bootstrap seam。
- 保持 desktop-only 初始化由 `application/desktop` 或等价 seam 持有。
- 只让 composition root 调用清晰的初始化入口。
- 用 guardrail 确认 iOS 支持没有引入新的 `state -> features`、`application -> features` 或 `core -> higher-layer` 反向依赖。

这是本 change 在 `evolve_modularity` 阶段的 scoped modularity improvement：即使不大规模重构，也要通过 seam 或 guardrail 防止平台接入让 composition root 更难维护。

## Risks / Trade-offs

- [Risk] `flutter create --platforms=ios .` 可能生成或修改 Xcode 工程、assets、Podfile、pubspec metadata，带来较大 diff。Mitigation: 后续 apply 阶段先生成并审查 diff，只保留公开基础 Runner 所需内容，避免无关 metadata churn。
- [Risk] iOS permission 参考 Android `full` 后过宽，导致审核或用户信任问题。Mitigation: 每个 `Info.plist` privacy key 必须对应公开功能 usage description，并由 `ios_public_shell_guardrail_test` 扫描禁止私有商业用途描述。
- [Risk] 公开 iOS Bundle ID `com.memoflow.hzc073` 与现有 Android applicationId 一致但 Apple 签名团队未确定。Mitigation: public spec 固定 bundle id，不把 Team ID、profile、certificate 或 App Store Connect 信息放进公开仓；实际签名由本地或私有发布配置处理。
- [Risk] Apple App Review 对外部支持链接、数字权益和 IAP 的规则复杂。Mitigation: 公开 iOS 壳不提供购买、恢复购买、价格或权益交换；涉及付费权益时由 Apple private overlay 使用 StoreKit 或按目标地区/渠道合规处理。
- [Risk] 旧 `private-macos-overlay-boundary` 名称保留但语义已升级，容易让读者误会。Mitigation: 本 change 的 delta spec 明确移除 macOS-only scaffolding 规则，并在 docs 中把描述改成 Apple private overlay；是否重命名 spec folder 可作为后续归档或治理清理。
- [Risk] private overlay seam 未来不够支撑 iOS 原生商业能力。Mitigation: 本 change 只批准现有 Dart overlay seam；任何新的原生 overlay seam 必须另行提案、说明 public build fallback 和 guardrail。

## Migration Plan

1. 先更新 OpenSpec delta specs 和 docs，把 Apple public shell / Apple private overlay 的规则写清楚。
2. 后续 apply 阶段再生成 `memos_flutter_app/ios/` 基础 Runner，配置 `MemoFlow` 和 `com.memoflow.hzc073`。
3. 审查 iOS `Info.plist`、entitlements、Xcode project 和 Podfile，确认只包含公开基础功能需要的权限和配置。
4. 增加 `ios_public_shell_guardrail_test` 与 public repo guardrail 扫描，阻止 StoreKit、商品、价格、收据、权益、签名秘密、release automation 泄漏。
5. 运行 `flutter analyze`、focused architecture tests，并在具备环境时运行 `flutter build ios --no-codesign` 或等价 smoke。
6. 私有 Apple overlay 在私有仓中适配 iOS/iPadOS 商业能力，不回写商业 runtime 到公开仓。

## Open Questions

- iOS public shell 首轮是否同时打开 iPadOS 设备族，还是只验证 iPhone 布局后再扩大测试矩阵？
- iOS share extension、home widget、App Group、iCloud Drive、Shortcuts/App Intents、Spotlight 是否属于后续独立 Apple ecosystem capability，而不是本次 public shell 基础范围？
- 私有仓实际目录和仓库名称是否同步从 `memoflow-macos-private` 改名为 Apple-wide 名称，还是先文档语义升级、仓库名延后调整？
