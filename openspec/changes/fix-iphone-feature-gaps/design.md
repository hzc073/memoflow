# Design: fix-iphone-feature-gaps

## Context

本 change 的平台范围是 iOS mobile：`TargetPlatform.iOS` 下的 `PlatformTarget.iPhone` 和 `PlatformTarget.iPad`。后续实现不得只处理 iPhone viewport，也不得把 iPadOS 留给另一个 change。

本次探索确认 iOS mobile 缺口主要分为三类：

- Native extension / channel 缺失：例如小组件需要 WidgetKit target，第三方分享需要 iOS Share Extension 或等价 handoff，铃声选择需要 iOS 支持或降级。
- 平台 gate 与 UI 可见性不一致：例如定位、扫码、提醒等入口在 UI 中可见，但底层 validator 或 scheduler 只允许 Android/Windows。
- 流程中段能力不完整：例如图片压缩有 Dart fallback 但部分格式/原图模式仍是 Android-only；第三方分享可以设计 native intake，但分享视频压缩默认只支持 Android，可能在 payload 进入后失败。

修复不能只在单个页面里补 `Platform.isIOS` 分支，否则会继续扩散耦合。需要把“当前平台是否可执行某个 feature，以及不可执行时怎么呈现”抽象为共享、可测试的 readiness seam，并要求本批次补齐 iOS mobile 核心能力。

## Goals

- iPhone and iPadOS 上所有可见功能入口都与真实可执行能力一致。
- 本批次补齐 WidgetKit、Share Extension/native handoff、iOS local notifications、定位/地图、二维码扫描、图片压缩和分享视频处理的 iOS mobile 路径。
- 只有明确平台硬限制或插件不可用时，才允许 hidden、disabled with reason 或 manual fallback；所有 fallback 必须记录原因并在 UI 中可见。
- 平台能力判断集中在 `memos_flutter_app/lib/platform_capabilities/`，避免 `features/*`、`application/*`、`state/*` 之间新增反向依赖。
- 保持 public repository 不含商业、订阅、StoreKit 或 private release 逻辑。

## Non-Goals

- 不在本 change 中改变 Memos server API、同步 route、request/response model 或 API compatibility 行为。
- 不把 iPadOS 拆成后续 change；iPhone and iPadOS 同属本批次。
- 不复制 iOS 专属 feature page tree，例如 `features_ios/`。
- 不引入 private/commercial hooks 到 public shell。
- 不要求 iOS 自定义通知铃声达到 Android ringtone picker 的能力；若 iOS 只能使用系统声音，UI 必须隐藏 Android-only ringtone picker 并说明差异。

## Decisions

### 1. iOS Mobile Scope Uses Existing Platform Targets

Readiness 判断 MUST 以 `TargetPlatform.iOS` 作为 iOS mobile 的基础范围，并在 UI 需要区分布局时消费既有 `PlatformTarget.iPhone`、`PlatformTarget.iPad` 和 `isAppleMobilePlatform` 概念。能力层不得只判断 `PlatformTarget.iPhone`，否则 iPadOS 会继续保留同类缺口。

### 2. Readiness Seam Lives Under `platform_capabilities`

新增或扩展 `memos_flutter_app/lib/platform_capabilities/` 下的纯 Dart seam。实现应暴露等价于以下最小模型的能力，不要求文件名完全一致，但调用方语义必须一致：

- `IosMobileFeatureId`: 标识 `homeWidgets`、`locationPicker`、`memoReminders`、`reminderRingtone`、`thirdPartyShareIntake`、`thirdPartyShareVideoCompression`、`qrScanner`、`imageCompression`。
- `PlatformFeatureReadinessStatus`: 固定状态集合为 `available`、`disabledWithReason`、`hidden`、`manualFallback`、`requiresNativeImplementation`。
- `PlatformFeatureReadiness`: 包含 feature id、status、reason code、native requirement、manual fallback description。

该 seam MUST NOT import `features/*`、`state/*`、`application/*` 或 `data/*`。Feature UI、settings page、startup coordinator 和 application service 只能消费 readiness 结果，不各自维护互相冲突的平台判断。

### 3. WidgetKit Is In Scope

本批次必须实现 WidgetKit target、共享数据写入路径和 WidgetKit timeline reload 路径。Flutter 侧 widget preview 和 settings page 必须消费 readiness seam。由于 iOS 不允许普通 app 直接把小组件添加到主屏，Android-style add action 在 iOS mobile 上必须替换为系统添加说明或 manual fallback，而不是展示不可执行按钮。

### 4. Share Extension and Share Video Handling Are In Scope

本批次必须实现 iOS Share Extension 或等价 native handoff，使 text/link/file payload 能进入现有 Flutter share flow。handoff 应使用 app group、shared container、URL scheme 或等价机制传递 payload，并在 startup recovery 中消费 pending payload。

分享视频附件属于同一条链路：iOS mobile 必须支持分享视频大小限制处理。若当前 `native_video_compress` 或等价 engine 可在 iOS 使用，则实现压缩路径；若插件存在硬限制，UI 和 share flow 必须给出可见失败原因或替代路径，不能让 compression service 静默返回 `null` 后丢失上下文。

### 5. iOS Local Notifications Are In Scope

iOS mobile 上的提醒设置不能只是保存偏好。Scheduler 必须完成 notification permission、initialize、schedule、cancel、update 和基础 activation routing。Android-only exact alarm、电池优化引导、自定义 ringtone picker 必须通过 readiness seam hidden 或 replaced with iOS-supported alternatives。iOS 默认策略是使用系统通知声音，不暴露 Android ringtone picker。

### 6. Location and QR Scanner Must Use Real iOS Capability

定位/地图选择必须移除 Android/Windows-only validator 限制，改为基于 iOS permission、provider key、embedded map host 和 WebView readiness 的能力判断。若某个 provider 在 iOS 不可用，只禁用该 provider 或入口，并显示原因。

二维码扫描必须基于 camera permission 和 scanner plugin readiness。`mobile_scanner` iOS 路径可用时，抽屉扫码、bridge 配对扫码和迁移扫码都必须启用；不可用时必须保留手动配对或文本输入 fallback。

### 7. Image Compression Separates Image and Shared Video Paths

iOS mobile 图片压缩必须区分 engine readiness、output format readiness 和 picker/original-mode readiness。Dart fallback 支持的 JPEG/PNG/TIFF 路径可以作为 available；Caesium FFI、WebP output、Android gallery toolbar 或 Android-only original-image 语义不得在 iOS mobile 上以同等能力展示。

分享视频压缩不属于图片压缩设置，但必须在同一 readiness inventory 中单独列出 `thirdPartyShareVideoCompression`，避免 Share Extension 修复后流程中段仍是 Android-only。

### 8. Modularity Guardrails

实现阶段若触及 `settings`、`home`、`memos`、`application` 或 `state`，必须至少完成以下一项：

- 将散落的平台判断提取到 `platform_capabilities` readiness seam。
- 删除或收敛 feature page 内重复平台 gate。
- 增加 architecture test 或 repo scan，阻止 `state -> features`、`application -> features`、`core -> higher-layer` 依赖恶化。
- 为 iPhone and iPadOS readiness 添加 focused widget/unit tests，覆盖 visible/disabled/hidden/fallback 状态。

## Alternatives Considered

- 只在每个页面加 `Platform.isIOS` 判断：实现快，但会继续造成 UI、settings、application service 和 native channel 之间状态不一致。
- 首批只做 honest UI 降级：可以快速消除误导，但用户明确要求本 change 补齐能力，因此不作为本批次策略。
- 完全隐藏所有疑似缺失功能：能快速消除误导，但会丢失定位、扫码、图片压缩、本地通知等可以补齐的 iOS mobile 能力。

## Risks

- WidgetKit 和 Share Extension 需要 Xcode target、entitlement、app group 和构建流程配合，可能影响 CI 或 release signing。
- iOS local notification 的精确性、权限提示和点击恢复语义不同于 Android，需要避免把 Android-only 设置直接映射到 iOS mobile。
- iOS 分享视频压缩依赖 native engine 能力；若插件不支持或输出不稳定，必须提供清楚的用户反馈和测试覆盖。
- Readiness seam 如果过度泛化会增加维护成本；实现阶段应保持模型小而可测，只覆盖本 change 明确列出的 feature ids。

## Migration Plan

1. 建立 iOS mobile readiness inventory 和 `platform_capabilities` seam，列出每个缺口的状态、native requirement 和 fallback reason。
2. 实现 WidgetKit target、共享数据和 timeline reload；同步修正 widgets settings UI。
3. 实现 Share Extension/native handoff，并补齐分享视频压缩或可见替代路径。
4. 实现 iOS local notifications、定位/地图选择、二维码扫描、图片压缩 options gating。
5. 补充 iPhone and iPadOS focused tests、architecture guardrail、`flutter analyze` 和相关 `flutter test`。
6. 确认未触碰 API compatibility 文件，且未引入 StoreKit、订阅、付费权益、receipt、paywall 或 private overlay 逻辑。
