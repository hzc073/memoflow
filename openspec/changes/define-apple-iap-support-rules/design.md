## Context

`define-support-memoflow-page-boundary` 已经把“支持 MemoFlow”从旧 `DonationDialog` 升级为独立支持页，并通过 `SupportMemoFlowExtension` 允许 private overlay 贡献 Apple 支持者区域。当前仍有一个关键规则需要冻结：Apple App Store 发布版里的“打赏开发者”是否和 `Pro` 功能增强一样走 IAP，以及公开仓是否继续保留外部付款入口。

基于当前产品方向和 App Store 审核边界，本设计采用更保守的规则：

- Apple App Store 版本中的支持/付款入口统一由 private overlay 的 IAP 支持中心承载。
- “请开发者喝咖啡 / 自愿打赏”在 Apple 版中也建模为 IAP tip，而不是外部付款链接或二维码。
- `Pro` 增强继续由 StoreKit 商品和 private entitlement layer 映射到 `AppCapability`。
- 公开仓仍保持 community build 可运行，不包含 StoreKit、商品 ID、价格、receipt 或真实权益状态。

当前相关约束：

- `apple-commercialization-capability-boundary` 已要求公开代码只消费 product-level `AppCapability`，不得读取订阅计划、商品 ID、StoreKit transaction、receipt、price、Family Sharing 或 buyout state。
- `private-macos-overlay-boundary` 要求商业集成通过批准 private hook 接入，公开仓不直接 import 私有商业模块。
- `macos-app-store-release-readiness` 要求公开 macOS shell 的 release permissions 保持商业中立。
- 私有 PRD 已确认 Apple 原生支付、年订阅、一次性买断、权益来源和 StoreKit 都属于 `/Users/mr.han/Desktop/memoflow-macos-private`。
- Apple Review Guidelines 当前允许使用 IAP 表达 developer tip，同时对外部购买链接和慈善募款有额外限制；实现阶段需要在提交前重新核对最新规则。

## Goals / Non-Goals

**Goals:**

- 明确 iPhone、iPad 和 macOS App Store 版本的“支持 MemoFlow”主付款路径必须走 private IAP 支持中心。
- 明确 Apple 版自愿打赏使用 IAP tip 商品，不承诺功能解锁、服务访问或权益状态。
- 明确 Apple 版 `Pro` 增强使用 private StoreKit 商品，并通过 private entitlement layer 映射到 `AppCapability`。
- 明确公益说明是项目承诺和透明记录，不是用户在 app 内直接向公益组织捐款。
- 明确公开赞赏 fallback 仍供 Android、Windows、Linux、web、side-load / non-App-Store public builds 使用，但 Apple App Store build 不默认显示支付宝链接、二维码或其他外部付款 CTA。
- 设计一个可独立进入的 public appreciation surface，避免 private IAP 页“跳到打赏页”时又回到 private contribution 主区。
- 收紧 public/private 和模块化边界，防止公开 settings shell 出现外部 Apple 付款风险或 StoreKit 泄漏。

**Non-Goals:**

- 不实现 StoreKit、商品目录、购买、恢复购买、receipt 校验或权益刷新。
- 不决定最终商品 ID、价格层级、订阅组、IAP product type、试用策略或 App Store Connect 配置。
- 不改变免费版基础记录、查看、编辑、本地库、基础导入导出和基础数据访问的长期可用承诺。
- 不把公益说明建模为用户直接捐赠公益组织，也不在本 change 中创建公益募款流程。
- 不在公开仓引入支付宝以外的新支付渠道，也不在 Apple App Store 版中默认启用任何外部付款 CTA。

## Decisions

### 1. Apple App Store 版支持入口统一进入 private IAP 支持中心

App Store 分发的 iPhone、iPad 和 macOS 版本不应根据公开页面 fallback 去展示外部付款链接或二维码。更稳的主路径是：

```text
Support MemoFlow entry
        │
        ▼
private Apple IAP support center
        │
        ├─ IAP tip / coffee support
        ├─ IAP Pro subscription / buyout
        ├─ restore purchase
        ├─ App Store subscription management
        └─ public-good / appreciation explanation
```

公开仓不负责判断“这是 App Store build 还是非 App Store build”的商业细节。公开仓只渲染 private contribution 或 route/action seam；private overlay 决定 Apple 发布版的真实支持中心。

Alternative considered: 公开仓写 `if (isApplePlatform) showIapPage()`。
Rejected because it会让 public settings shell 知道商业入口，并且很容易继续扩展成 price/product/entitlement 分支，违背现有边界。

### 2. IAP tip 和 IAP Pro 是两类不同商品语义

Apple 版“打赏开发者”应是 non-entitlement support product：

```text
IAP tip
├─ voluntary
├─ no feature unlock
├─ no Pro capability
├─ no service access promise
└─ may contribute to maintenance / public-good commitment
```

`Pro` 商品则通过 private entitlement layer 映射能力：

```text
IAP Pro product
        │
        ▼
private entitlement state
        │
        ▼
AppCapability decisions
        │
        ▼
public feature gates
```

这样可以同时满足两个产品目标：用户可以纯支持项目，也可以购买增强能力；公开仓只看到 capability decision，不知道 StoreKit 或商品细节。

Alternative considered: 把打赏和 Pro 合并成一个“支持者”商品。
Rejected because它会模糊用户预期：打赏不应暗示解锁，Pro 不应被包装成纯情绪支持。

### 3. 公开赞赏 fallback 拆成可独立进入的 public appreciation surface

当前 `SupportMemoFlowScreen` 的组织是：

```text
if private contribution exists:
  render private support
else:
  render public appreciation fallback
```

这会导致 private IAP 页如果“转到打赏说明”，仍然回到 private contribution，而不是公开赞赏说明。后续实现应把公开赞赏区域拆成可独立进入的 surface，例如：

```text
SupportMemoFlowScreen
├─ public brand narrative
├─ private contribution slot OR public fallback
└─ base capability promise

PublicAppreciationSurface
├─ voluntary support explanation
├─ public-good note
├─ public-good record link
├─ foundation official link
└─ channel-specific support CTA
```

在 Apple App Store build 中，`PublicAppreciationSurface` 可以保留说明、公益承诺、记录入口和“也可以通过 IAP 请开发者喝咖啡”的回到 IAP action，但不得默认显示支付宝链接或二维码。非商店公开构建可显示公开赞赏链接或桌面动态二维码。

Alternative considered: 在 private contribution 内复制一份公开赞赏 UI。
Rejected because会让同一套公益/赞赏文案出现两个 owner，后续审核规则或文案调整容易漂移。

### 4. 外部支付宝链接按渠道 gate，而不是按 Apple 平台粗暴 gate

支持链接 `https://qr.alipay.com/tsx16856ygfke5rugz1ao4a` 仍可作为 public appreciation fallback 的数据源，但 Apple App Store 版不得默认展示它作为付款 CTA。更准确的判断模型是：

```text
public appreciation CTA policy
├─ Apple App Store build: IAP tip only; no Alipay CTA by default
├─ Apple non-App-Store / local public build: may show public fallback if no private support contribution
├─ Android / Windows / Linux / web community build: public appreciation fallback
└─ future approved entitlement / region exception: explicit separate rule
```

公开仓可以保留非商业 fallback；private overlay 或后续发布配置负责 Apple App Store 渠道规则。任何外部购买 link entitlement、地区例外或美国 storefront 例外都必须另开 change 记录，不能默默启用支付宝 CTA。

### 5. 公益说明保持模糊承诺口径，不做 app 内公益募款

公益说明应避免承诺具体比例、金额或固定触发条件。推荐口径是：

```text
如项目产生盈利，MemoFlow 会将其中一部分投入公益事业或公共善意项目。
```

但 Apple IAP 商品和付款页不得表达为“用户正在向公益组织捐款”。建议文案边界：

- 可以说：项目盈利的一部分会被用于公益事业、公共善意项目或长期透明记录。
- 可以提供：公益记录、年份说明、受益方、日期和金额区间等透明信息。
- 不应说：固定比例会被捐出、固定金额会被捐出、达到某个固定条件后必然捐出、此 IAP 是公益捐款、用户正在直接捐给公益组织、购买某商品即完成慈善捐赠。

### 6. Guardrail 以 public blocker + private verification 两层执行

公开仓 guardrail 继续阻止：

- StoreKit import / IAP plugin dependency。
- product ID、price、receipt、transaction、purchase / restore implementation。
- raw entitlement state、subscription/buyout/family sharing state。
- Apple App Store build 中直接显示支付宝付款 CTA 的公开商业分支。

私有 overlay verification 覆盖：

- IAP support center 存在并作为 Apple App Store 版主支持入口。
- IAP tip 不授予 `AppCapability`。
- IAP Pro 权益通过 private entitlement layer 映射到 `AppCapability`。
- restore purchase、unavailable、expired、refunded 等状态有清晰显示。
- IAP 页进入 public appreciation explanation 时不会显示外部支付宝付款 CTA，除非测试显式启用批准渠道策略。

## Dependency Direction

目标方向：

```text
features/settings/support surface
        │
        ▼
private_hooks/private_extension_bundle_provider
        │
        ▼
PrivateExtensionBundle / SupportMemoFlowContribution
        ▲
        │ overlay replacement
memoflow-macos-private StoreKit support center
```

公开层只依赖公开 seam；私有层实现 IAP 支持中心并通过 seam 贡献 UI 或 route/action。`state`、`application`、`core` 不应为了 IAP 支持中心 import `features/settings` 页面，也不应让公开 app shell 读取 raw commercial state。

结构改善点：

- 将 public appreciation fallback 从 `SupportMemoFlowScreen` 的局部分支抽成可独立复用 surface，减少商业/公益/公开赞赏规则藏在 widget 条件分支中。
- 如果现有 `SupportMemoFlowContribution` 不足以表达“打开 public appreciation explanation”或“回到 IAP tip”，后续应扩展 module boundary model，而不是让 private overlay 直接 import 公共页面内部私有 widget。
- 收紧 architecture / public shell guardrails，防止 touched support surface 在 `evolve_modularity` 阶段继续累积商业分支。

## Risks / Trade-offs

- [Risk] Apple 规则持续变化，外部链接可用范围随 storefront / entitlement 调整。→ Mitigation: 本 change 默认禁用 Apple App Store 版外部支付宝 CTA；任何例外必须另开 change 并重新核对 Apple 最新规则。
- [Risk] IAP tip 和 Pro 商品并存会让用户误解打赏能解锁功能。→ Mitigation: tip 商品文案必须声明不影响基础功能、不授予 Pro；Pro 商品单独展示能力差异。
- [Risk] 公益说明被理解成 app 内公益募款。→ Mitigation: 商品名和付款页避免“公益捐赠”语义；公益仅作为项目承诺和透明记录。
- [Risk] public appreciation surface 抽取扩大公开 interface。→ Mitigation: 只抽取非商业说明和 channel-safe CTA policy，不暴露 StoreKit 或权益状态。
- [Risk] 私有 overlay 需要同时实现 macOS 和未来 iOS/iPadOS，工作量增加。→ Mitigation: 先以 macOS private overlay 完成 IAP support center 的模型和测试，再复用到 iOS/iPadOS。
- [Risk] 现有 `define-support-memoflow-page-boundary` 与本 change 对 Apple fallback 口径有冲突。→ Mitigation: 本 change 明确作为后续收紧规则；实施时同步更新支持页 boundary artifact 或归档后的 baseline spec。

## Migration Plan

1. 在公开仓先完成 spec / guardrail：明确 Apple App Store 版不得默认显示支付宝付款 CTA，公开 shell 不包含 StoreKit 细节。
2. 抽取 public appreciation surface，并使其支持 channel-safe CTA policy。
3. 在 private overlay 中将当前 `MemoFlow Pro` / support placeholder 升级为 IAP support center。
4. 在 private overlay 中接入 StoreKit product catalog、purchase、restore、entitlement refresh 和 App Store 管理订阅入口。
5. 为 IAP tip、IAP Pro、restore purchase、公益说明和 Apple App Store no-Alipay-CTA 增加 focused tests。
6. 提交 App Store 前重新核对 Apple Review Guidelines、目标 storefront、entitlement 和商品元数据。

## Open Questions

- IAP tip 商品最终使用 consumable、non-consumable 还是其他 StoreKit product type，需要在 private StoreKit 设计中决定。
- Apple App Store 版的 public appreciation explanation 是否展示“其他平台可通过官网支持”，需要提交前结合审核风险决定。
- 公益记录首版是官网静态页、应用内 WebView 还是外部浏览器打开，仍需由官网/发布策略决定。
