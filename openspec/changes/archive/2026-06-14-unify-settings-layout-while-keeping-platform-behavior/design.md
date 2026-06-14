## Context

当前 settings UI 已经有 `SettingsPage`、`SettingsSection`、`SettingsNavigationRow`、`SettingsToggleRow`、`SettingsFormFieldRow`、`SettingsFieldBlock` 等共享 seam，也已经通过前序 changes 修正了 WebDAV 服务器连接页和 full-width field block 对齐问题。

剩余问题是跨平台设置页排版仍部分依赖底层平台列表组件默认几何：iPhone 路径会进入 `CupertinoListSection` / `CupertinoListTile` / `CupertinoTextField`，Android/Material 路径会进入 `ListTile` / `TextField`。这些组件默认字号、内边距、行高、分割线和输入框基线不同，导致同一 settings 页面在 iPhone 与 Android 上看起来不像同一个产品体系。

目标不是取消平台适配，而是收窄平台差异边界：

```text
Settings page intent
        │
        ▼
settings-owned layout seams
  ├─ typography
  ├─ section geometry
  ├─ row shell
  ├─ field block
  └─ divider/card hierarchy
        │
        ▼
platform/adaptive behavior slots
  ├─ Switch
  ├─ picker/dialog/route
  ├─ text input behavior
  └─ back/navigation behavior
```

依赖方向保持：

```text
features/settings pages
        │ pass label/value/controller/callback
        ▼
features/settings/settings_ui.dart
        │ owns settings layout/typography/row-field geometry
        ▼
platform/widgets/*
        │ owns adaptive behavior widgets
        ▼
Flutter widgets
```

在 `evolve_modularity` 阶段，本 change 的模块化改进是继续把 settings 视觉规则从页面和 platform 默认布局中收敛到 `settings_ui.dart` seam，并用 guardrail 阻止页面私有 row/input/card surface 回流。

## Core Principles

- `settings` seam 负责视觉层级和几何排版：分组标题、行标题、右侧 value、说明文字、section 边距、row padding/min height、field block、输入框高度/padding、卡片/分割线层级都应由 `settings_ui.dart` 或 approved settings seam 控制。
- `platform` seam 负责平台行为和原生交互感：`Switch`、picker/dialog、route/back 行为、输入法、文本编辑、焦点和必要的平台反馈继续由 `platform/` widgets 或 approved adaptive seam 控制。
- 页面只表达 settings intent：页面传入 label、value、controller、callback、enabled、semantic variant 等意图，不在页面里重新定义普通 settings row/card/input 的视觉系统。
- 如果视觉统一和平台默认控件几何冲突，优先让 settings seam owns layout，platform seam 只作为行为 slot 或 renderer；如果平台行为必须保留差异，需要在 design/tasks/guardrail 中记录例外。

## Goals / Non-Goals

**Goals:**

- 保留 adaptive 行为：`Switch`、返回行为、弹窗 / Picker、平台 route、输入法和文本编辑行为继续走现有 platform/settings seam。
- 统一 settings 自家排版：分组标题、行标题、右侧选项/值、说明文字、输入框高度、输入框 padding、section 边距、卡片圆角、分割线层级。
- 让已迁移 settings subpages 通过 settings-owned row shell / field block 获得一致排版，而不是依赖 `CupertinoListTile` / Material `ListTile` 默认字号和 padding。
- 继续使用现有主题颜色体系和 settings tokens，不新增颜色系统，不修改全局主题文件。
- 保持业务行为、Provider ownership、controller/callback、validation、normalization、persist key、API adapter 和 WebDAV/service 语义不变。
- 更新 focused tests 和 guardrail，覆盖 iPhone/Android 下排版统一与 adaptive 行为保留。

**Non-Goals:**

- 不把 Android 强行做成 iOS，或把 iPhone 强行做成 Material。
- 不修改全局 `ThemeData`、`ColorScheme`、`MemoFlowPalette`、`AppColors`、ThemeExtension 或主题 token。
- 不改数据模型、API compatibility、WebDAV 协议、数据库 schema、Provider 状态结构、持久化 key。
- 不处理非 settings 页面的一般 Typography 或全局控件体系。
- 不新增 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching。

## Decisions

### Decision 1: 平台 adaptive 只负责行为，settings seam 负责排版

`PlatformSwitch`、`showPlatformPicker`、`showPlatformAlertDialog`、`buildPlatformPageRoute`、`PlatformTextField` 等继续表达平台行为。设置页内部的 section/row/field 几何则由 settings-owned seam 固定。

Rationale: 用户要的是“交互像平台，页面像同一个 App”。如果继续让平台 list row 默认布局决定字号和 padding，iPhone/Android 永远会出现不可控差异。

Alternative considered: 继续完全依赖 `CupertinoListSection` / Material `ListTile`。这能保留原生味道，但无法解决设置页主次层级不一致和灰色容器错位的问题。

### Decision 2: 引入或强化 settings-owned row shell

实现时优先在 `settings_ui.dart` 中引入私有或公共的 settings row shell，例如 `_SettingsRowShell` 或等价结构，统一：

- horizontal padding
- vertical padding / min height
- title/value/description/trailing slot
- divider inset
- enabled opacity
- touch target

`SettingsNavigationRow`、`SettingsValueRow`、`SettingsToggleRow`、`SettingsMenuRow`、`SettingsInfoRow` 等应逐步委托给 row shell。平台控件继续作为 trailing/content slot。

Rationale: `SettingsRowTitle` 和 `SettingsRowDescription` 只能统一文字本身，无法统一 `ListTile` 和 `CupertinoListTile` 的内边距、baseline 和分割线。row shell 是解决跨平台视觉差异的必要 seam。

Alternative considered: 只调字号。字号能缓解“主次不一致”，但无法统一输入框高度、section 边距、卡片和分割线层级。

### Decision 3: Typography 使用 settings 私有常量或局部 token，不改全局 Theme

建议在 `settings_ui.dart` 内部定义 settings typography/layout 常量或私有 helper，例如：

```text
section header  13 / 600 / muted
row title       15 / 600 / main
row value       13-14 / 500 / muted
field value     14 / 600 / main
placeholder     13 / 400 / muted
description     12 / 400 / muted
```

这些值只服务 settings seam，不写入全局 `ThemeData` 或 `ColorScheme`。

Rationale: 全局主题影响面过大。用户明确要求不重做颜色和主题系统；本 change 是 settings-specific layout/typography convergence。

Alternative considered: 修改全局 `TextTheme`。这会影响非 settings 页面，风险大且偏离请求。

### Decision 4: `SettingsFieldBlock` 继续负责 full-width input geometry

`SettingsFieldBlock` 和 `_SettingsTextField` 继续作为 full-width input 的统一入口。需要统一输入框高度、padding、hint、value、suffix icon、helper/error 的层级，并覆盖 Material 与 Cupertino 路径。

Rationale: 前序 change 已经验证 field block 能解决 WebDAV 灰色输入背景错位。这里继续扩展到跨平台输入框高度/padding/文字层级一致。

Alternative considered: 让每个页面自己设置 input padding。会再次扩散页面私有视觉规则。

### Decision 5: 分批迁移，先共享 seam 后页面确认

先改 `settings_ui.dart` 共享 seam，再用 focused tests 确认高感知页面仍保留行为：

- WebDAV 服务器连接页
- AI proxy
- image bed
- location provider key
- custom notification
- server settings / shortcut editor 等代表性 inline/numeric 页面

Rationale: 共享 seam 改动会影响多个设置页。通过代表性页面测试可以在不逐页手调的情况下捕捉主要风险。

### Decision 6: Guardrail 明确防止页面私有布局回流

`settings_ui_drift_guardrail_test.dart` 应继续阻止 migrated settings files 新增：

- page-local `_RowShell` / `_FieldBlock` / `_InputCard`
- raw `TextField` / `TextFormField` / `CupertinoTextField`
- bare `Switch` / `Switch.adaptive`
- direct `PlatformListSection` / raw Material/Cupertino list layout for ordinary settings rows
- direct palette/surface styling for ordinary settings row/card/divider

Rationale: 这符合 `evolve_modularity` 下“触碰热点必须让结构更好”的要求。

## Risks / Trade-offs

- [Risk] 改 row shell 会影响大量设置页高度和间距。→ Mitigation: 先定义固定 row geometry，跑 representative focused tests 和 full `flutter test`，必要时分批迁移 row 类型。
- [Risk] iPhone 原生 grouped list 味道变弱。→ Mitigation: 保留 adaptive 行为和平台控件，视觉统一仅作用于产品自家设置内容排版。
- [Risk] desktop 设置页变得过高。→ Mitigation: row shell 可以保留 desktop density 参数，但字号/层级仍统一。
- [Risk] `CupertinoTextField` 与 Material `TextField` 无法完全等高。→ Mitigation: 在 `PlatformTextField` seam 内统一 content padding/decoration，测试关注可感知高度和对齐，而不是像素完全相等。
- [Risk] 误触业务逻辑。→ Mitigation: implementation tasks 明确禁止改 Provider、repository、model、API/WebDAV service、persist key，页面只传原有 controller/callback。

## Migration Plan

1. 盘点 `SettingsSection`、`PlatformListSection`、`PlatformListSectionRow`、`SettingsRowTitle`、`SettingsRowDescription`、`SettingsFieldBlock`、`SettingsNavigationRow`、`SettingsToggleRow`、`SettingsMenuRow` 的当前布局职责。
2. 在 `settings_ui.dart` 中建立 settings typography/layout constants 和 row shell。
3. 迁移核心 row seam 到 row shell，保留 public constructor 和参数语义。
4. 调整 `SettingsFieldBlock` / `_SettingsTextField` 的高度、padding、value/hint/helper/error 层级。
5. 检查 WebDAV、AI proxy、image bed、location、custom notification、server settings 等代表性页面是否自然继承统一排版。
6. 更新 tests 和 guardrail。
7. 运行 OpenSpec validate、`flutter analyze`、focused tests、guardrails，必要时运行 full `flutter test`。

Rollback: 如果某类 row 在某个平台出现明显回归，优先在 row shell 增加平台/密度参数或延后该 row 类型迁移，不回退到页面私有布局。

## Open Questions

- row shell 是否应作为 public `SettingsRowShell` 供少量特殊页面使用，还是先保持 private。
- desktop row density 是否需要单独的 compact profile，还是统一 mobile/desktop geometry 足够。
- `PlatformListSection` 是否应继续作为 settings section 的底层容器，还是 `SettingsSection` 完全 owns section card/divider geometry。
