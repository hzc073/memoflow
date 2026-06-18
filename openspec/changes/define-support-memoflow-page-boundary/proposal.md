## Why

当前设置页里的“充电站”入口会直接打开 `DonationDialog`，语气偏玩笑和短弹窗，已经不足以承载新的产品意图：MemoFlow 需要一个更正式、更克制、Apple 风格的“支持 MemoFlow”入口。

这个入口未来会同时服务两类支持关系：

- Apple 平台私有商业版：macOS 现阶段，以及未来 iOS / iPadOS，用户通过成为支持者获得 Apple 平台特有优化和支持，真实购买、恢复购买、价格、StoreKit 和权益判断由私有仓 `memoflow-macos-private` 负责。
- 桌面端 / Android / 公开构建：Windows 和 macOS 的桌面设置窗口也应能直接查看“支持 MemoFlow”页面；非 Apple 公开构建保留自愿赞赏路径、项目支持说明和公益公示入口，但不提供商业解锁或权益判断。旧 `DonationDialog`、旧二维码资产和保存流程将被移除，首版统一使用用户确认的支付宝外部支持链接作为非 Apple fallback 数据源：移动端直接打开链接，桌面端显示由该链接动态生成的二维码。Apple runtime 的付款入口由 `define-apple-iap-support-rules` 收紧为 private IAP 或 free-safe 说明。

需要先把规则写清楚，避免后续实现时把商业逻辑、价格、权益状态或平台付费分支写入公开仓。

## What Changes

- 将设置首页入口的产品语义从“充电站”调整为“支持 MemoFlow”。
- 定义 `SupportMemoFlow` 独立页面规则：页面使用干净、克制的 Apple 风视觉语气，同时保持跨平台可用和公开仓可构建。
- 定义平台和仓库边界：
  - Apple 私有版的“成为支持者”、Apple 平台优化、购买、恢复购买、价格、权益状态和 StoreKit MUST 属于 private overlay。
  - Windows / macOS 桌面设置窗口 MUST 通过通用 desktop settings surface 暴露“支持 MemoFlow”页面，不得做成 Windows 专属入口；没有 private overlay 时 macOS MUST 走 free-safe 支持说明，不显示外部付款 CTA。
  - Windows / Android / Linux / web 等非 Apple 公开构建的支持页面 MUST 走公开赞赏 fallback，移除旧二维码资产展示与保存流程；移动端打开外部赞赏链接，桌面端显示由该链接动态生成的二维码。
  - 首版公开赞赏链接 SHALL 使用用户确认的支付宝外部支持链接 `https://qr.alipay.com/tsx16856ygfke5rugz1ao4a`。
  - 公开仓 MUST NOT 根据 macOS / iOS 平台本身直接显示商业价格、商品、权益或购买 UI。
- 定义 private bundle seam 方向：公开页面可以提供一个支持页贡献区域，但真实商业支持内容必须由 `PrivateExtensionBundle` 或等价批准 seam 贡献。
- 约束文案：支持是对项目维护和平台优化的帮助，不得把免费能力包装成付费门票，也不得在支持页展示免费能力承诺说明。
- 约束公益说明：公开页面 MAY 说明“如项目产生盈利，MemoFlow 会将其中一部分捐赠给北京韩红爱心慈善基金会并公示”，并将公益公示入口指向官网占位页或后续正式公益记录页；基金会外部链接 SHOULD 指向官方地址而不是搜索引擎跳转链接。
- 追加平台展示统一规则：iPhone、iPad、macOS public、macOS private、Android、Windows、Linux、web MUST 共享同一支持页外壳，并通过 feature-local support policy 决定 public fallback 的链接、二维码或 Apple free-safe 说明。
- 收敛 Apple 私有版入口：`Support MemoFlow` SHALL be the primary support entry；private overlay SHALL inject the IAP support center through `SupportMemoFlowContribution` and SHALL NOT add a duplicate primary settings entry for the same support center.
- 保持公益区首版隐藏：独立 public-good section 不进入主体验；页面只保留轻量维护和公益承诺文案，避免在记录页未完善前制造过强承诺。

## Capabilities

### New Capabilities

- `support-memoflow-entry`: 约束设置里的“支持 MemoFlow”入口、独立支持页面、公开赞赏 fallback 和 Apple 私有商业支持贡献区的职责边界。

### Modified Capabilities

- `apple-commercialization-capability-boundary`: 后续实现若需要 private 支持页贡献 seam，必须延续既有商业能力边界：公开仓只定义 seam，不承载 StoreKit、价格、商品 ID、权益状态或购买/恢复购买逻辑。
- `platform-adaptive-ui-system`: 支持页面属于高感知 settings surface，后续实现必须使用 settings/platform 语义组件或批准的页面 seam，避免把整页做成与设置系统割裂的营销页。

## Impact

- Affected product surfaces:
  - Settings home entry currently labeled `msg_charging_station`
  - Desktop settings window navigation for Windows and macOS
  - deleted `DonationDialog` / legacy donation QR support flow
  - Future `SupportMemoFlow` independent settings page
  - External support link `https://qr.alipay.com/tsx16856ygfke5rugz1ao4a`
  - Beijing Han Hong Love Charity Foundation official site link
  - Future public-good record page, for example `https://memoflow.app/support/public-good`
  - Private overlay support / subscription center contribution
- Affected public code in future implementation:
  - `memos_flutter_app/lib/features/settings/settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/desktop_settings_window_app.dart`
  - `memos_flutter_app/lib/application/desktop/desktop_settings_window.dart`
  - deleted `memos_flutter_app/lib/features/settings/donation_dialog.dart`
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
- 不改变现有免费能力范围。
- 不在本 change 决定后续多渠道支付平台、Google Play 分发版本处理或官网公益记录实现。
- 不让公开仓根据 `AccessDecision.source`、raw entitlement state、商品 ID 或价格做 UI 可见性、路由或解锁判断。
- 不启用独立公益区，不新增公益募款流程，不清理历史归档 artifact 中对旧“充电站”或 `DonationDialog` 的记录。
