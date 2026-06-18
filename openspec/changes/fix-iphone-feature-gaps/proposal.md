# Change: fix-iphone-feature-gaps

## Why

当前 `TargetPlatform.iOS` 构建中存在多处“UI 已出现，但运行能力缺失或被 Android/Windows 条件限制”的功能。范围同时包含 `PlatformTarget.iPhone` 和 `PlatformTarget.iPad`，不再只修 iPhone。典型表现包括小组件页面、定位/地图选择、笔记提醒、第三方分享、扫码配对/迁移、图片压缩选项、分享视频压缩等入口在设置、抽屉、编辑器或操作菜单中可见，但 iOS mobile 侧缺少对应原生 target、MethodChannel handler、平台能力声明，或现有平台校验直接排除了 iOS。

这种状态会让用户误以为功能可用：开关可能只是保存了偏好，按钮可能进入 unsupported 分支，分享 payload 可能进入流程后才遇到 Android-only 压缩路径，或设置项展示了当前平台无法执行的能力。本 change 将探索性方向升级为可直接实现的全量 iOS mobile 修复规格：本批次必须补齐可实现能力，只有明确平台硬限制或插件不可用时才允许禁用、隐藏或手动 fallback，并必须给出可见原因。

## What Changes

- 新增 `ios-mobile-platform-feature-readiness` capability，用于约束 iPhone and iPadOS 上 UI 入口、平台能力、原生实现、压缩链路和 fallback 的一致性。
- 在 `memos_flutter_app/lib/platform_capabilities/` 新增或扩展层级安全的 platform feature readiness seam，覆盖小组件、定位/地图选择、提醒、本地通知/铃声、第三方分享、分享视频压缩、二维码扫描、图片压缩等当前已发现的 iOS mobile 缺口。
- 修复“可见但不可执行”的 UI 状态：每个入口必须处于 `available`、`disabledWithReason`、`hidden`、`manualFallback` 或 `requiresNativeImplementation` 之一，不能只有数据开关、silent no-op 或 late failure。
- 本批次补齐 WidgetKit 小组件 target、共享数据路径、timeline reload 路径和验证记录；iOS 不能由 app 直接添加系统小组件时，设置页必须呈现系统添加说明而不是 Android-style add action。
- 本批次补齐 iOS Share Extension 或等价 native handoff，使 text/link/file payload 能进入现有 Flutter share flow，并覆盖分享视频附件的压缩、大小限制和可见失败/替代路径。
- 本批次补齐 iOS local notifications 的 permission、schedule、cancel、update 和基础 activation routing；Android-only exact alarm、电池优化、自定义 ringtone picker 不得展示给 iOS mobile。
- 本批次补齐 iOS mobile 定位/地图选择、二维码扫描、图片压缩能力；不支持的 engine、format、picker 语义必须禁用或替换为 iOS-supported alternative。
- 增加 iPhone and iPadOS focused tests 和架构 guardrail，防止后续新增 UI 入口时再次绕开 readiness seam。
- 保持 public/private 分离：本 change 不引入 StoreKit、订阅、付费权益、receipt、paywall 或 private overlay 逻辑。

## Capabilities

- `ios-mobile-platform-feature-readiness`: 新增规格，定义 iPhone and iPadOS 上 UI 可见性、运行能力、原生实现、压缩链路、fallback 和测试 guardrail 的验收标准。

## Impact

- 预计涉及的 Flutter 代码区域包括 `memos_flutter_app/lib/platform_capabilities/`、`memos_flutter_app/lib/platform/platform_target.dart` 的现有 iOS mobile 判定消费点、`memos_flutter_app/lib/features/settings/`、`memos_flutter_app/lib/features/home/`、`memos_flutter_app/lib/features/memos/`、`memos_flutter_app/lib/features/reminders/`、`memos_flutter_app/lib/features/share/`、`memos_flutter_app/lib/application/widgets/`、`memos_flutter_app/lib/application/attachments/`、`memos_flutter_app/lib/data/location/`、`memos_flutter_app/lib/state/system/`。
- 预计涉及 iOS 原生工程文件：WidgetKit target、Share Extension、`AppDelegate.swift`、`Info.plist`、extension entitlements、shared app group 或等价 handoff 配置。
- 不触碰 server API、route adapter、request/response model 或 `memos_flutter_app/lib/data/api`，除非后续用户明确批准。
- 由于当前架构阶段为 `evolve_modularity`，任何触及 `settings`、`home`、`memos`、`application` 或 `state` 的实现任务都必须让对应区域保持等同或更好的结构，通过集中 seam、去除散落平台判断或新增 guardrail 完成。
