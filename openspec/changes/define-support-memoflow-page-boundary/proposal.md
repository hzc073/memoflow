## Why

当前设置页里的“充电站”入口会直接打开 `DonationDialog`，语气偏玩笑和短弹窗，已经不足以承载新的产品意图：MemoFlow 需要一个更正式、更克制、Apple 风格的“支持 MemoFlow”入口。

这个入口未来会同时服务两类支持关系：

- Apple 平台私有商业版：macOS 现阶段，以及未来 iOS / iPadOS，用户通过成为支持者获得 Apple 平台特有优化和支持，真实购买、恢复购买、价格、StoreKit 和权益判断由私有仓 `memoflow-macos-private` 负责。
- Windows / Android / 公开构建：保留自愿赞赏路径，但从弹窗升级为与“支持 MemoFlow”一致的独立页面，表达为公开赞赏和项目维护支持，不提供商业解锁或权益判断。现有二维码支持方式将被外部赞赏链接替代，首版使用用户确认的支付宝外部支持链接。

需要先把规则写清楚，避免后续实现时把商业逻辑、价格、权益状态或平台付费分支写入公开仓。

## What Changes

- 将设置首页入口的产品语义从“充电站”调整为“支持 MemoFlow”。
- 定义 `SupportMemoFlow` 独立页面规则：页面使用干净、克制的 Apple 风视觉语气，同时保持跨平台可用和公开仓可构建。
- 定义平台和仓库边界：
  - Apple 私有版的“成为支持者”、Apple 平台优化、购买、恢复购买、价格、权益状态和 StoreKit MUST 属于 private overlay。
  - Windows / Android / 公开构建的支持页面 MUST 走公开赞赏 fallback，移除现有二维码展示与保存流程，改为打开外部赞赏链接。
  - 首版公开赞赏链接 SHALL 使用用户确认的支付宝外部支持链接 `https://qr.alipay.com/tsx16856ygfke5rugz1ao4a`。
  - 公开仓 MUST NOT 根据 macOS / iOS 平台本身直接显示商业价格、商品、权益或购买 UI。
- 定义 private bundle seam 方向：公开页面可以提供一个支持页贡献区域，但真实商业支持内容必须由 `PrivateExtensionBundle` 或等价批准 seam 贡献。
- 约束文案：基础记录能力长期可用；支持是对项目维护和平台优化的帮助，不得把基础功能包装成付费门票。
- 约束公益说明：公开页面 MAY 说明“当支持收入覆盖当年的必要维护成本后，超出部分的 50% 将用于公益捐赠”，并将公益记录入口指向官网占位页或后续正式公益记录页。

## Capabilities

### New Capabilities

- `support-memoflow-entry`: 约束设置里的“支持 MemoFlow”入口、独立支持页面、公开赞赏 fallback 和 Apple 私有商业支持贡献区的职责边界。

### Modified Capabilities

- `apple-commercialization-capability-boundary`: 后续实现若需要 private 支持页贡献 seam，必须延续既有商业能力边界：公开仓只定义 seam，不承载 StoreKit、价格、商品 ID、权益状态或购买/恢复购买逻辑。
- `platform-adaptive-ui-system`: 支持页面属于高感知 settings surface，后续实现必须使用 settings/platform 语义组件或批准的页面 seam，避免把整页做成与设置系统割裂的营销页。

## Impact

- Affected product surfaces:
  - Settings home entry currently labeled `msg_charging_station`
  - `DonationDialog` / legacy donation QR support flow
  - Future `SupportMemoFlow` independent settings page
  - External support link `https://qr.alipay.com/tsx16856ygfke5rugz1ao4a`
  - Future public-good record page, for example `https://memoflow.app/support/public-good`
  - Private overlay support / subscription center contribution
- Affected public code in future implementation:
  - `memos_flutter_app/lib/features/settings/settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/donation_dialog.dart` or replacement page
  - `memos_flutter_app/lib/private_hooks/private_extension_bundle.dart` if a support-page contribution seam is added
  - `memos_flutter_app/lib/module_boundary/...` if a new contribution model is needed
  - i18n files for “支持 MemoFlow” and donation/support copy
- Affected private code in future implementation:
  - `/Users/mr.han/Desktop/memoflow-macos-private/overlay/memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart`
  - future private StoreKit / entitlement / subscription center modules
- Architecture phase: `evolve_modularity`.
- Modularity checklist impact:
  - 触及 checklist `4`：支持页公共叙事、平台分流和商业贡献规则不得散落在 widget 局部 helper 中；应通过页面 seam / private bundle seam 表达。
  - 触及 checklist `6`：Apple 私有支持中心与公开设置页协作应通过 bundle/provider contribution seam，而不是直接 import private page。
  - 触及 checklist `8`、`10`：后续实现需要增加或收紧 guardrail，防止公开 settings shell 引入商业泄漏。

## Non-Goals

- 本 change 不接入 StoreKit，不实现价格、购买、恢复购买或权益判断；公开仓只实现支持页外壳、公开赞赏 fallback 和 private contribution seam。
- 不决定最终价格、商品 ID、订阅组、免费试用、App Store Connect 配置或权益映射。
- 不改变基础记录、查看、编辑、本地库、基础导入导出等永久免费能力。
- 不在本 change 决定后续多渠道支付平台、Google Play 分发版本处理或官网公益记录实现。
- 不让公开仓根据 `AccessDecision.source`、raw entitlement state、商品 ID 或价格做 UI 可见性、路由或解锁判断。
