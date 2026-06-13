## Why

当前“支持 MemoFlow”边界已经把公开赞赏 fallback 和 Apple 私有商业贡献区分开，但还没有明确 Apple App Store 发布版中“打赏”和 `Pro` 增强都应走 IAP。由于 App Store 对外部支付链接、开发者 tip 和慈善/公益表述有明确审核边界，需要在实现 StoreKit 前先冻结规则，避免把支付宝链接、二维码或公益承诺误带进 Apple 付款流程。

## What Changes

- 定义 Apple 平台支持规则：通过 App Store 分发的 iPhone、iPad 和 macOS 版本 SHALL 使用 private overlay 提供的 IAP 支持中心作为主要支持/付款入口。
- 将 Apple 版“自愿打赏 / 请开发者喝咖啡”建模为 IAP tip 商品，而不是内嵌外部付款链接、二维码或外部付款跳转。
- 将 Apple 版 `Pro` 功能增强建模为 private overlay 中的 IAP 订阅 / 买断商品，并通过 private entitlement layer 映射到 `AppCapability`，公开仓不接触商品 ID、价格、StoreKit、receipt 或真实权益状态。
- 约束公益说明：支持页 MAY 保留“如项目产生盈利，会将部分盈利投入公益事业或公共善意项目”的模糊说明，但不得承诺固定比例、固定金额或固定触发条件；Apple IAP 商品不得伪装成用户直接向公益组织捐赠，公益记录应作为项目承诺说明和外部透明记录。
- 明确非 Apple / 非 App Store 构建仍可使用公开赞赏 fallback；Apple App Store 构建不得显示支付宝外部支付 CTA，除非后续有明确批准的 Apple entitlement、地区政策或审核结论。
- 要求后续实现把 `SupportMemoFlowScreen` 中公开赞赏 fallback 拆成可独立进入的 public appreciation surface，使 private IAP 页可以安全链接到“其他支持方式 / 公益说明”而不会循环回 IAP 主区。
- 收紧 guardrail 和测试口径：公开仓继续禁止 StoreKit/IAP 实现细节；private overlay 测试覆盖 IAP tip、IAP Pro、恢复购买、权益映射和 Apple 版不展示外部支付宝付款入口。

## Capabilities

### New Capabilities

- `apple-iap-support-rules`: 约束 Apple App Store 版本的 IAP 支持中心、IAP tip、IAP Pro 增强、公益说明、外部赞赏 fallback 和跨仓边界。

### Modified Capabilities

- `apple-commercialization-capability-boundary`: 扩展 Apple 商业化边界，明确 subscription center / support center 可包含 IAP tip 和 IAP Pro，但所有商品、价格、购买、恢复购买、receipt、权益状态和 StoreKit 仍必须留在 private overlay。

## Impact

- Affected product surfaces:
  - “支持 MemoFlow”设置入口和独立支持页。
  - Apple private overlay 中的支持者中心 / 订阅中心 / IAP 付款页。
  - 公开赞赏 fallback、基金会官网入口、公益说明和公益记录入口。
  - macOS 当前私有版，以及未来 iPhone / iPad App Store 版本。
- Affected public code in future implementation:
  - `memos_flutter_app/lib/features/settings/support_memoflow_screen.dart`
  - `memos_flutter_app/lib/module_boundary/support_memo_flow_contribution.dart`
  - `memos_flutter_app/lib/private_hooks/private_extension_bundle.dart`
  - relevant settings tests and architecture guardrails under `memos_flutter_app/test/...`
- Affected private code in future implementation:
  - `/Users/mr.han/Desktop/memoflow-macos-private/overlay/memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart`
  - future private StoreKit / entitlement / product catalog / IAP support center modules.
- Architecture phase: `evolve_modularity`.
- Modularity checklist impact:
  - 触及 checklist `4`：IAP 支持规则、公开赞赏 fallback 和公益说明不得散落在 widget 局部 helper 中，后续实现应通过 support surface seam / private contribution seam 表达。
  - 触及 checklist `6`：公开支持页和私有 Apple IAP 页面协作必须通过 `PrivateExtensionBundle`、`SupportMemoFlowContribution` 或后续批准的 route/action seam，不得直接 import private 页面。
  - 触及 checklist `8`、`10`：后续实现需要增加或收紧 guardrail，防止公开仓引入外部 Apple 支付风险或 StoreKit 商业泄漏。
