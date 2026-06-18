# Tasks: fix-iphone-feature-gaps

## 1. Inventory and Seam

- [x] 1.1 建立 iOS mobile feature readiness inventory，覆盖 `PlatformTarget.iPhone` 和 `PlatformTarget.iPad` 下的小组件、定位/地图选择、提醒/本地通知/铃声、第三方分享、分享视频压缩、二维码扫描、图片压缩。
- [x] 1.2 在 `memos_flutter_app/lib/platform_capabilities/` 新增或扩展层级安全的 readiness seam，表达固定状态集合 `available`、`disabledWithReason`、`hidden`、`manualFallback`、`requiresNativeImplementation`。
- [x] 1.3 为 readiness seam 定义 feature id、status、reason code、native requirement、manual fallback description，并记录允许的调用方向。
- [x] 1.4 确保 readiness seam 不 import `features/*`、`state/*`、`application/*`、`data/*`，并添加 architecture guardrail 或 repo scan 覆盖该边界。

## 2. Native iOS Mobile Integrations

- [x] 2.1 实现 WidgetKit target、共享数据写入路径和 WidgetKit timeline reload 路径。
- [x] 2.2 实现 iOS Share Extension 或等价 native handoff，使 text/link/file payload 能进入现有 Flutter share flow。
- [x] 2.3 为 Share Extension payload 建立 pending payload 存储、startup recovery 和文件复制/缓存策略，保证 app cold start 后仍能恢复。
- [x] 2.4 实现 iOS local notification permission、initialize、schedule、cancel、update 和基础 activation routing。
- [x] 2.5 补齐 iOS camera/location/notification/share extension 所需 `Info.plist`、entitlement、app group 或等价配置。

## 3. iOS Mobile Feature Fixes

- [x] 3.1 小组件页面消费 readiness seam；iOS mobile 展示 WidgetKit 状态和系统添加说明，不展示不可执行的 Android-style add action。
- [x] 3.2 定位和地图选择移除 Android/Windows-only validator 限制，按 provider key、permission、embedded map host、WebView readiness 启用或禁用。
- [x] 3.3 提醒设置和 memo reminder action 消费 readiness seam；iOS mobile 支持真实本地通知调度，Android-only exact alarm、电池优化和 ringtone picker 不展示。
- [x] 3.4 第三方分享设置消费 readiness seam；iOS mobile 只有在 native handoff 和 startup recovery 可用时允许启用。
- [x] 3.5 分享视频压缩补齐 iOS mobile 路径；如 native engine 存在硬限制，share flow 必须显示可见失败原因或替代路径，不能 silent no-op。
- [x] 3.6 抽屉扫码、bridge 配对扫码和迁移扫码按 scanner readiness 展示；`mobile_scanner` iOS 路径可用时启用，否则保留手动配对或文本输入 fallback。
- [x] 3.7 图片压缩设置只展示 iOS mobile 支持的 engine、format、picker/original-mode 选项；WebP/native-only/Android gallery toolbar 语义必须隐藏、禁用或替换。
- [x] 3.8 Memo editor、memo action menu、settings subpage、startup coordinator 和 application services 的相关入口统一消费 readiness seam，删除重复平台 gate。

## 4. Tests and Verification

- [x] 4.1 为 readiness seam 添加 unit tests，覆盖 iPhone and iPadOS 的每个 feature id 和每种 readiness status。
- [x] 4.2 为 settings、home drawer、memo editor、memo action menu、widget page 添加 iPhone and iPadOS focused widget/unit tests，覆盖 available/disabled/hidden/fallback 状态。
- [x] 4.3 为 WidgetKit data update、Share Extension intake、share video compression、location validator、reminder scheduler、scanner readiness、image compression readiness 添加 focused tests 或可复现 smoke notes。
- [x] 4.4 运行 `flutter analyze`。
- [x] 4.5 运行 `flutter test`，或在实现批次中说明为什么只运行 focused tests。
- [x] 4.6 运行 `openspec validate fix-iphone-feature-gaps --type change --strict --no-interactive`。
- [x] 4.7 检查本 change 未触碰 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`，且未引入 StoreKit、订阅、付费权益、receipt、paywall 或 private overlay 逻辑。
