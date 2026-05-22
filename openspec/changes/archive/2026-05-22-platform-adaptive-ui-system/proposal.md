## Why

当前桌面端体验仍明显带有移动端页面放大的痕迹：全宽按钮、卡片、bottom sheet、单列设置流和触摸优先交互在 macOS / Windows 大窗口下显得笨重，且各页面对平台差异的处理分散。用户希望后续围绕一个长期方向持续改造，而不是每次只修一个页面后丢失整体目标。

当前架构阶段为 `evolve_modularity`，基线 modularity score 为 `4/10`。本变更会长期触及 `home`、`settings`、`memos`、desktop shell、platform adapters 等耦合热点，因此必须把平台差异收敛到稳定 seam，并在每个迁移批次中保持 touched area equal or better structured。

## What Changes

- 建立 `platform-adaptive-ui-system` 作为跨平台 UI 改造总纲，后续桌面端、Apple 平台和移动端差异都围绕同一套 adaptive UI 语义推进。
- 定义平台 UI 分层：共享业务状态不变，平台差异集中在 `platform/` adapters、desktop shell host、adaptive components 和 feature-owned composition seams。
- 将“按平台不同界面”从散落的页面条件分支，转为可复用的语义组件与 shell 策略，例如 adaptive scaffold、command bar、primary action、dialog、popover/sheet、list section、master-detail、form controls。
- 分阶段迁移高感知区域：app shell / navigation、onboarding / login、settings、memo list / detail / editor、collections / resources / review / AI 等。
- 为迁移进度建立 inventory 和验收标准，避免一个 change 只完成局部页面后丢失后续工作上下文。
- 增加或收紧 guardrails，防止平台 adapter 反向依赖 feature/state/application/data，防止商业/private 逻辑进入 public shell。
- 不一次性重写所有页面；每个批次必须小步迁移、可验证、可回滚。

## Capabilities

### New Capabilities

- `platform-adaptive-ui-system`: 约束跨平台 UI 体系、平台分层、adaptive component seam、迁移优先级、批次验收、进度追踪和架构守卫。

### Modified Capabilities

- `apple-platform-ui-adaptation`: 后续 Apple UI 适配应纳入总的 platform adaptive UI 体系，避免形成 Apple-only 平行页面树。
- `desktop-shell-host-boundary`: 桌面 shell host 后续应作为 macOS / Windows / Linux 外壳策略的组合入口，承载平台差异而不是让 feature pages 直接导入平台外壳实现。
- `desktop-layering-governance`: 平台 UI 改造批次必须声明触及共享业务、桌面通用、平台外壳或私有商业层，并保持依赖方向可审查。

## Impact

- 主要影响 `memos_flutter_app` 的 UI 与 shell 层：
  - `lib/platform/**`
  - `lib/features/home/**`
  - `lib/features/settings/**`
  - `lib/features/memos/**`
  - `lib/features/collections/**`
  - `lib/features/resources/**`
  - `lib/features/review/**`
  - `lib/features/onboarding/**`
  - `lib/application/desktop/**`
  - `macos/Runner/**`、`windows/runner/**` 中必要的窗口 / 菜单 / shell 集成
- 不改变 API 请求/响应、server route adapters、version compatibility logic 或 `memos_flutter_app/lib/data/api`。
- 不新增 StoreKit、subscription、entitlement、receipt、paywall、price、product ID 或其他商业化逻辑。
- 不新增 `features_ios/`、`features_ipad/`、`features_macos/`、`features_windows/` 这类完整复制页面树。
- 后续实现批次如果触碰已知 coupling hotspots，必须包含 seam extraction、guardrail tightening 或其他 touched-area modularity improvement。

## Non-Goals

- 不要求一次性完成所有平台 UI 重构。
- 不要求 Flutter 页面 100% 模拟原生控件；目标是符合平台交互模型和视觉密度，而不是机械复刻系统 App。
- 不在本总纲里实现具体页面改造；具体实现应通过 tasks 分批推进。
- 不改变业务功能范围、账号模型、同步模型、API 兼容策略或公开/私有仓分工。
