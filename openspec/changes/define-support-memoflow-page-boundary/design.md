## Context

现有入口位于设置首页，“充电站”点击后直接调用 `DonationDialog.show(context)`。这个实现有三个局限：

1. 产品语义偏短期玩笑，不能承载“支持 MemoFlow 长期维护”的正式叙事。
2. 弹窗空间有限，不适合表达 Apple 平台支持者、公开赞赏、基础功能长期可用等边界。
3. Apple 私有商业版需要 StoreKit、权益、价格和恢复购买，但公开仓明确不能包含这些实现细节。

当前可用边界：

- `PlatformTarget` 已能区分 `android`、`iPhone`、`iPad`、`macOS`、`windows` 等目标。
- `PrivateExtensionBundle` 当前可贡献 settings entries、app ready hook 和 diagnostics access boundary。
- `apple-commercialization-capability-boundary` 已要求 subscription / upgrade UI 通过 private bundle contribution，而不是公开 settings shell 商业分支。
- `DesktopSettingsWindowApp` 已为 Windows、macOS 等桌面运行时提供独立设置窗口，但当前桌面 pane / `DesktopSettingsWindowTarget` 尚未包含“支持 MemoFlow”入口；如果只补 Windows 会遗漏 macOS 的同类桌面体验。

## Product Shape

统一入口：

```text
设置
└─ 支持 MemoFlow

桌面设置窗口
└─ 支持 MemoFlow
```

页面内部按“公开外壳 + 可选私有贡献 + 公开 fallback”组织：

```text
SupportMemoFlowScreen
┌────────────────────────────────────────────┐
│ 公共品牌叙事                                │
│ - MemoFlow 是简单、克制、长期可用的记录工具   │
│ - 基础记录能力长期可用                       │
│ - 支持帮助项目维护和平台体验优化             │
├────────────────────────────────────────────┤
│ Private support contribution slot           │
│ - Apple 私有版：成为支持者 / Pro / StoreKit   │
│ - 由 memoflow-macos-private 提供              │
├────────────────────────────────────────────┤
│ Public appreciation fallback                 │
│ - Windows / macOS desktop / Android / 公开构建 │
│ - 移动端打开外部赞赏链接，桌面端显示动态二维码 │
└────────────────────────────────────────────┘
```

桌面设置窗口应把支持页作为通用 desktop surface，而不是 Windows 专属设置：

```text
DesktopSettingsWindowApp
├─ Account
├─ Preferences
├─ Desktop
├─ AI
├─ Help & Diagnostics
├─ Import / Export
├─ About
└─ Support MemoFlow
      └─ SupportMemoFlowScreen(showBackButton: false)
```

## Decisions

1. **入口命名统一为“支持 MemoFlow”。**

   “充电站”可以作为内部小彩蛋或历史文案退出主入口。主入口应清楚表达页面目的，避免用户以为这是工具、诊断或电量设置。

2. **公开仓拥有支持页外壳和公开赞赏 fallback。**

   公开仓可以展示：

   - “支持 MemoFlow”标题和品牌叙事。
   - 基础功能长期可用的承诺。
   - 项目维护、适配、公益记录等非商业说明。
   - 外部赞赏链接，首版使用 `https://qr.alipay.com/tsx16856ygfke5rugz1ao4a`。
   - 桌面端基于外部赞赏链接动态生成二维码，便于用户用手机扫码。
   - 北京韩红爱心慈善基金会官方链接，使用官方地址而不是搜索引擎跳转链接。
   - 公益说明：如项目产生盈利，MemoFlow 会将其中一部分捐赠给北京韩红爱心慈善基金会并公示。

   公开仓不得展示：

   - 旧二维码图片资产、旧二维码保存流程。
   - StoreKit purchase / restore。
   - App Store product ID、订阅组、价格、买断价格。
   - raw subscription / buyout / trial / refunded / Family Sharing state。
   - 基于权益状态决定商业 UI 的分支。

3. **Apple 平台“成为支持者”由 private overlay 贡献。**

   macOS 当前私有商业版和未来 iOS / iPadOS 的支持者体验应由 `/Users/mr.han/Desktop/memoflow-macos-private` 中的 private overlay 实现。公开仓只提供批准 seam，例如未来可扩展 `PrivateExtensionBundle`：

   ```text
   PrivateExtensionBundle
   ├─ settingsEntries(...)
   ├─ onAppReady(...)
   ├─ diagnosticsAccessBoundary
   └─ supportMemoFlowContribution(...)  ← future seam, if approved
   ```

   该 seam 返回 UI contribution 或 route intent；公开页面只渲染 contribution，不知道价格、商品 ID、StoreKit 或权益状态。

4. **平台分流应基于“private contribution 是否存在”，而不是公开仓硬编码 Apple 商业分支。**

   公开仓可以判断平台用于布局、文案细节、外部链接打开能力或合规提示，但不得写：

   ```text
   if (isApplePlatform) showStoreKitSupport()
   ```

   更稳的语义是：

   ```text
   if (privateSupportContribution != null) renderPrivateSupport()
   else renderPublicDonationFallback()
   ```

   这样公开 Apple 构建没有 private overlay 时仍然保持 free-safe，不误显示商业能力。

5. **Windows / Android 保留自愿赞赏支持，但升级为独立页面。**

   非 Apple 平台的体验不应继续是小弹窗；它应使用同一支持页的视觉系统，让用户看到完整说明、感谢文案、公益说明和“可以不支持也继续使用”的承诺。

   该页面移除旧 `DonationDialog`、旧 `donation_qr.png` 展示和保存流程，统一以外部赞赏链接作为数据源；移动端直接打开链接，桌面端显示由该链接动态生成的二维码：

   ```text
   supportUrl: https://qr.alipay.com/tsx16856ygfke5rugz1ao4a
   charityUrl: https://www.hhax.org/
   publicGoodUrl: https://memoflow.app/support/public-good
   ```

   `supportUrl` 是用户确认的外部赞赏链接，`charityUrl` 指向北京韩红爱心慈善基金会官方站点。页面内仍应保留基础功能不受影响的说明、维护成本说明和公益公示入口。若未来面向 Google Play、App Store 或其他有审核规则的渠道分发，MUST 复核对应渠道规则；Apple App Store 版应由 private IAP 支持中心接管，不显示公开外部付款 CTA。

6. **桌面设置窗口新增通用支持入口，而不是 Windows 专属入口。**

   Windows 和 macOS 都会使用独立桌面设置窗口，因此支持页入口应挂在 `DesktopSettingsWindowApp` 的通用 pane / target 模型上。公开 macOS 构建当前没有 StoreKit 商业能力时，仍然显示公开赞赏 fallback；后续如 private overlay 贡献 Apple 支持者 UI，也应通过 `SupportMemoFlowExtension` 或等价批准 seam 进入。

   推荐语义：

   ```text
   DesktopSettingsWindowTarget.supportMemoFlow
          │
          ▼
   _DesktopSettingsPane.supportMemoFlow
          │
          ▼
   SupportMemoFlowScreen(showBackButton: false)
   ```

   该路径不得写成 `if (Platform.isWindows) showSupportPage()`，也不得因为 `TargetPlatform.macOS` 自动显示商业购买 UI。macOS 是否展示商业内容只取决于 private contribution 是否存在。

7. **公益说明使用保守承诺，并指向明确接收方。**

   页面可以展示公益说明，但应写成：

   > 如项目产生盈利，MemoFlow 会将其中一部分捐赠给北京韩红爱心慈善基金会并公示。

   该表述避免承诺固定比例、固定金额或固定触发条件。“查看公益公示”首版可指向官网占位入口，后续官网应展示可追踪记录，例如年份、公益接收方、捐赠日期和金额或区间。

8. **视觉方向为干净 Apple 风，而不是厚重手账页。**

   后续实现 SHOULD 采用：

   - 大留白、浅灰/白背景、清晰层级。
   - SF 风格排版或平台默认字体。
   - 细线图标、轻量材质、克制红色 CTA。
   - 少量品牌意象，例如小苗、流动线条、MemoFlow logo，但避免一页塞满装饰。

   后续实现 SHOULD NOT：

   - 做成营销落地页 hero。
   - 使用大量水彩、手写体、花纹、过厚卡片和情绪化装饰。
   - 把设置页改成与现有 settings system 割裂的整页广告。

## Dependency Direction

预期方向：

```text
features/settings/support_page
        │
        ▼
private_hooks/private_extension_bundle_provider
        │
        ▼
PrivateExtensionBundle interface
        ▲
        │ overlay replacement
memoflow-macos-private/active_private_extension_bundle.dart
```

公开 settings feature 可以依赖公开 private hook interface，因为这是既有批准 seam。私有 overlay 替换 `active_private_extension_bundle.dart`。公开仓不得 import private repository 路径、StoreKit 实现或商业模块。

## Risks / Trade-offs

- [Risk] 公开支持页不小心写入价格或“年度支持者”文案，形成商业泄漏。Mitigation: spec 和 guardrail 明确阻止 price / product ID / subscription wording 进入公开 shell；价格放 private overlay。
- [Risk] 同一入口在不同构建表现不同，测试和截图容易混淆。Mitigation: public fallback 和 private contribution 分别验证，页面上只暴露“支持 MemoFlow”统一入口。
- [Risk] 外部付款入口在应用商店政策上产生风险。Mitigation: 公开外部赞赏入口只面向非商店公开构建；Apple App Store 版由 private IAP 支持中心接管；其他商店分发前必须复核目标渠道规则。
- [Risk] 公益承诺如果没有记录页会削弱信任。Mitigation: 首版可使用占位官网入口，但正式发布前应补充公益公示页或明确“记录准备中”的状态。
- [Risk] 为了 private contribution seam 修改 `PrivateExtensionBundle` 可能扩大公共接口。Mitigation: seam 只表达 support page contribution，不暴露商业状态；同时增加商业泄漏 guardrail。
- [Risk] 桌面设置窗口左侧 pane 继续增多，降低扫描效率。Mitigation: “支持 MemoFlow”属于高感知入口，优先作为独立 pane；如果后续桌面设置导航过密，再统一评估分组或排序，而不是把支持页做成 Windows 专属分支。

## Open Questions

- 公开 Apple 构建没有 private overlay 时，是否展示普通赞赏 fallback，还是展示“Apple 支持者能力准备中”的静态说明？
- private support contribution 是直接返回完整 section widget，还是返回 route/action model，由公开页面用统一组件渲染？
- 支持页是否只优先完善中文，还是同步补齐所有现有 locales？
