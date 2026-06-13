## 1. 规则确认

- [x] 1.1 确认设置入口统一命名为“支持 MemoFlow”，不再以“充电站”作为主入口名称。
- [x] 1.2 确认公开仓支持页只承载品牌叙事和公开赞赏 fallback，不包含价格、StoreKit、商品 ID、购买、恢复购买或权益判断。
- [x] 1.3 确认 Apple 平台私有商业支持者体验由 `/Users/mr.han/Desktop/memoflow-macos-private` 的 private overlay 实现。
- [x] 1.4 确认 Windows / Android 走公开赞赏支持页，且赞赏不承诺数字功能、权益、解锁或服务交换；桌面端展示动态二维码，移动端直接打开链接。
- [x] 1.5 确认公开支持页移除旧 `DonationDialog`、旧 `donation_qr.png` 展示与保存流程。
- [x] 1.6 确认公益说明口径为“如项目产生盈利，MemoFlow 会将其中一部分捐赠给北京韩红爱心慈善基金会并公示”。
- [x] 1.7 确认桌面端支持页入口应覆盖 Windows 和 macOS 的 `DesktopSettingsWindowApp`，不做 Windows 专属 UI；macOS 没有 private 商业贡献时显示公开赞赏 fallback。

## 2. Future Public Implementation Tasks

- [x] 2.1 将设置首页“充电站”入口迁移为“支持 MemoFlow”入口，并导航到独立页面而不是直接打开 dialog。
- [x] 2.2 新增或替换公开 `SupportMemoFlow` settings page，使用干净 Apple 风视觉语气和 settings/platform 语义组件。
- [x] 2.3 移除支持页里的旧 donation QR 资产展示、保存和扫码说明；移动端公开赞赏主操作为打开外部支持链接，桌面端显示由该链接动态生成的二维码。
- [x] 2.4 如需要 private 支持区，扩展 `PrivateExtensionBundle` 或等价批准 seam，让 private overlay 能贡献支持页 section / route / action。
- [x] 2.5 确保公开页面根据 private contribution 是否存在选择展示，不根据 Apple 平台本身硬编码商业购买 UI。
- [x] 2.6 增加“公益说明”“查看基金会官网”和“查看公益公示”入口；公示入口首版可指向 `https://memoflow.app/support/public-good` 或官网支持页中的公益记录锚点。
- [x] 2.7 在 `DesktopSettingsWindowApp` 中新增通用“支持 MemoFlow”桌面 pane，渲染 `SupportMemoFlowScreen(showBackButton: false)`，并覆盖 Windows 和 macOS 桌面设置窗口。
- [x] 2.8 扩展 `DesktopSettingsWindowTarget`，增加通用 support target / payload，使主窗口或菜单后续可以直接路由到桌面支持页。

## 3. Future Private Implementation Tasks

- [ ] 3.1 在 `/Users/mr.han/Desktop/memoflow-macos-private` 中把 `MemoFlow Pro` 占位入口升级为 Apple 支持者 / 订阅中心体验。
- [ ] 3.2 在 private overlay 中实现 StoreKit purchase / restore / product display / entitlement refresh。
- [x] 3.3 在 private overlay 中提供 Apple 平台优化和支持者能力说明，覆盖 macOS 当前范围和未来 iOS / iPadOS 方向。
- [x] 3.4 确保 private overlay 只通过批准 seam 进入公开 app，不修改公开 `settings_screen.dart` 来写商业分支。

## 4. Guardrails / Verification

- [x] 4.1 增加或收紧公开仓商业泄漏 guardrail，阻止 settings/support public shell 出现 StoreKit、product ID、receipt、purchase / restore implementation、hardcoded commercial price、raw entitlement state。
- [x] 4.2 增加 focused tests 或 widget tests，覆盖 public build 中“支持 MemoFlow”入口打开公开赞赏 fallback，移动端不渲染二维码，桌面端渲染动态二维码。
- [x] 4.3 增加 focused tests 或 private overlay tests，覆盖 private contribution 存在时公开页面只渲染 contribution，不读取 raw commercial state。
- [x] 4.4 增加或确认测试覆盖公开赞赏链接使用用户确认的外部支持 URL，且按钮文案不使用购买、解锁、会员、权益等交换型表达。
- [x] 4.5 从 `memos_flutter_app` 运行 `flutter analyze` 和相关 focused tests；正式 PR 前运行 `flutter test`。
- [x] 4.6 检查 diff，确认未触碰 API compatibility 文件、WebDAV 协议、数据库 schema，且公开仓未引入 subscription / billing / entitlement / paywall / StoreKit / price / product ID 逻辑。
- [x] 4.7 增加 focused widget tests，覆盖 Windows 和 macOS 的桌面设置窗口可以显示并进入 `SupportMemoFlowScreen`，且公开 fallback 不渲染商业购买 UI。
