## 1. 规则对齐

- [ ] 1.1 复核 Apple Review Guidelines、目标 storefront、external purchase link entitlement 和慈善/公益相关限制，确认 Apple App Store 版默认不展示支付宝外部付款 CTA。
- [ ] 1.2 对齐 `define-support-memoflow-page-boundary` 的支持页规则，明确本 change 收紧 Apple App Store 版付款路径：IAP tip 和 IAP Pro 均由 private overlay 承载。
- [ ] 1.3 确认 Apple App Store build、Apple non-App-Store build、Android、Windows、Linux、web 的 public appreciation CTA policy 归属和默认行为。
- [ ] 1.4 确认公益说明文案口径：如项目产生盈利，会将部分盈利投入公益事业或公共善意项目；不得承诺固定比例、固定金额或固定触发条件，也不得把 Apple IAP 商品表述为用户直接公益捐赠。

## 2. Public Support Surface

- [ ] 2.1 从 `SupportMemoFlowScreen` 中抽取可独立进入的 public appreciation surface，避免 private contribution 存在时无法进入公开赞赏/公益说明。
- [ ] 2.2 为 public appreciation surface 增加 channel-safe CTA policy，使 Apple App Store 版默认隐藏支付宝链接和二维码，非 Apple / approved public fallback 继续可显示外部支持链接。
- [ ] 2.3 保持 public build free-safe：没有 private overlay 时 Apple 平台不得推断 IAP 可用，也不得构造 StoreKit、价格、购买或恢复购买 UI。
- [ ] 2.4 如现有 `SupportMemoFlowContribution` 不足以表达 private IAP 页打开 public appreciation explanation，扩展 `module_boundary` route/action seam，但不暴露商品、价格、StoreKit 或权益状态。
- [ ] 2.5 更新公开支持页文案，区分“自愿支持项目”、“Pro 功能增强”和“公益承诺”，并保持基础功能长期可用说明。

## 3. Private Apple IAP Support Center

- [ ] 3.1 在 `/Users/mr.han/Desktop/memoflow-macos-private` 中将当前 `MemoFlow Pro` / support placeholder 升级为 private Apple IAP support center。
- [ ] 3.2 在 private overlay 中定义 IAP tip / coffee support 商品模型，确保 tip 不映射任何 `AppCapability`、不解锁 `Pro`、不承诺服务访问。
- [ ] 3.3 在 private overlay 中定义 IAP Pro 订阅 / 买断商品模型，并通过 private entitlement layer 映射到 approved `AppCapability` decisions。
- [ ] 3.4 在 private overlay 中实现 purchase、restore purchase、entitlement refresh、unavailable / expired / refunded / trial 状态显示和 App Store 管理订阅入口。
- [ ] 3.5 在 private IAP support center 中提供 public appreciation / public-good explanation 入口，并确保 Apple App Store channel 下不显示支付宝付款 CTA。

## 4. Guardrails / Tests

- [ ] 4.1 增加或收紧公开仓 architecture / public shell guardrail，阻止 StoreKit、IAP dependency、product ID、price、receipt、transaction、purchase / restore implementation、raw entitlement state 进入 public runtime code。
- [ ] 4.2 增加公开仓 focused widget tests，覆盖 public appreciation surface 可独立进入，private contribution 存在时不会递归回 IAP 主区。
- [ ] 4.3 增加公开仓 focused tests，覆盖 Apple App Store channel policy 下不显示 `https://qr.alipay.com/tsx16856ygfke5rugz1ao4a`、Alipay QR 或外部付款 CTA。
- [ ] 4.4 增加公开仓 focused tests，覆盖 Android / Windows / Linux / web 或 approved public fallback 仍可显示公开赞赏 fallback、基金会官网入口和公益公示入口，且不承诺功能解锁。
- [ ] 4.5 增加 private overlay tests，覆盖 IAP tip 不授予 `AppCapability`，IAP Pro entitlement 正确映射能力，restore purchase 刷新权益且 public code 不读取 raw commercial state。
- [ ] 4.6 增加 private overlay tests，覆盖 IAP support center 的公益说明不把 IAP 商品表达为用户直接公益捐赠。

## 5. Verification

- [ ] 5.1 从仓库根目录运行 `openspec status --change define-apple-iap-support-rules`，确认 proposal、design、specs、tasks 状态完整。
- [ ] 5.2 从仓库根目录运行 OpenSpec 校验命令，确认 `apple-iap-support-rules` 和 `apple-commercialization-capability-boundary` delta specs 可归档。
- [ ] 5.3 从 `memos_flutter_app` 运行相关 focused tests，至少覆盖 support page、desktop settings support entry、public shell guardrails 和 private hook contract。
- [ ] 5.4 从 `memos_flutter_app` 运行 `flutter analyze`；正式 PR 前运行 `flutter test`。
- [ ] 5.5 检查 diff，确认未触碰 API compatibility 文件、WebDAV 协议、数据库 schema，且公开仓未引入 StoreKit、IAP、subscription、billing、entitlement、receipt、paywall、price、product ID 或外部 Apple 支付分支。
- [ ] 5.6 App Store 提交前人工复核 Apple Review Guidelines、商品元数据、公益说明、外部链接、隐私文案和目标 storefront 规则。
