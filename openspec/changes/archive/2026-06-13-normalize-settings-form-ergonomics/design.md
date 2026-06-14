## Context

`platformize-settings-subpages` 归档后，设置子页面已经具备 platform-safe 控件基础：`SettingsPage`、`SettingsSection`、`SettingsMenuRow`、`SettingsOptionChipGroup`、`SettingsAction`、`SettingsFormDialog` 等 seam 能避免 Apple mobile 上的 `No Material widget found`。但复核发现第二层问题仍然存在：

```text
平台安全
  └── 控件不会崩溃

表单可用性
  ├── 字段排版符合内容长度
  ├── 输入触区足够大
  ├── 长值不会撑破容器
  ├── 日期/时间 picker 与设置页一致
  └── 设置入口页面不像另一套 UI
```

典型问题包括：

- `WebDavSyncScreen` 的用户名、密码、根路径使用页面私有 `_InputRow`，输入框位于 list tile subtitle 且 `InputBorder.none`，在 iOS 下触区显得很薄。
- `WebDavSyncScreen` 的 `_SelectRow` 右侧 value 未统一限宽，长路径、URL 或状态值可能超出容器。
- `SettingsInputRow` 本身仍偏“标题 + subtitle 无边框输入”，不适合所有设置字段。
- `ReminderSettingsScreen`、`MemoReminderEditorScreen`、`CustomNotificationScreen` 从设置入口进入，但仍使用 22px 圆角阴影卡片、页面私有 row、raw `showDatePicker` / `showTimePicker` 和 Material button styling。

当前架构阶段是 `evolve_modularity`，本 change 触碰 `features/settings` 和 settings-adjacent `features/reminders` 视觉热点。改动应把通用排版逻辑收敛到 settings/platform seam，避免继续在页面内复制字段布局。依赖方向应保持：

```text
features/settings 或 features/reminders
        │ 传入 label/controller/value/callback
        ▼
features/settings/settings_ui.dart
        │ 统一字段排版、tokens、触区、长值约束
        ▼
platform/widgets/*
        │ 只处理平台表达，不导入 features/state/application/data
        ▼
Flutter platform widgets
```

## Goals / Non-Goals

**Goals:**

- 建立设置字段排版规则，让短文本、短数字、长文本、密钥/密码、多行文本、长值展示、日期/时间选择分别走合适的 settings seam。
- 让 WebDAV 用户名、Host、Port、Pair code、保留版本数等短值可使用右侧 inline 排版，同时让 URL、路径、密码、API Key 等长/敏感字段使用完整输入排版。
- 修复 WebDAV 长值超出容器、输入触区过小、字体层级不协调的主要问题。
- 将 AI proxy、image bed、location key、Memoflow Bridge、shortcut/server 数字输入等设置字段纳入同一排版体系。
- 让 reminder 设置相关页面作为 settings-adjacent surfaces 使用一致的 settings row/action/picker/form 语法。
- 增加 focused tests 和 guardrail，保护目标文件不回到小触区、未限宽长值、raw date/time picker、页面私有卡片体系。

**Non-Goals:**

- 不重写 WebDAV、reminder scheduler、AI proxy、image bed、shortcut、server settings 的业务逻辑。
- 不改变 WebDAV protocol、backup archive format、sync/restore semantics、reminder scheduling semantics、API adapters 或 database schema。
- 不把全应用所有 `PlatformTextField` 一次性替换；只处理设置页和设置入口体验里的高感知字段。
- 不新增 subscription、billing、entitlement、paywall、StoreKit、private overlay 或 `AccessDecision.source` business branching。
- 不强制所有页面完全原生 iOS 视觉；目标是设置表单一致、触区稳定、长值安全、平台 picker 统一。

## Decisions

### Decision: 字段按内容语义选择排版，而不是按页面统一套模板

实现时应至少支持以下字段语义：

| 字段类型 | 推荐排版 | 例子 |
| --- | --- | --- |
| 短文本 | 左 label + 右侧 inline 输入 | 用户名、Host、Pair code、快捷方式名称 |
| 短数字 | 左 label + 右侧 compact numeric 输入 | Port、保留版本数、过去多少天、策略 ID |
| 长文本 | label 上方 + 完整输入框 | URL、根路径、测试 URL、API 地址 |
| 密钥/密码 | 完整输入框，支持 suffix action 或隐藏 | Password、API Key、Security Key |
| 多行文本 | label + 大输入区域 | AI 个人资料、反馈备注、通知正文 |
| 长值展示 | 右侧限宽省略或下方 description | 导出路径、WebDAV 路径、Webhook URL |
| 日期/时间 | value row + platform/settings picker | 提醒时间、日期范围、勿扰时间 |

用户名放右侧是合理的，但这不代表所有 WebDAV 输入都应右侧。服务器地址和根路径天然较长，应使用完整输入。密码带显示/隐藏 action，也更适合完整输入或 masked secure field。

### Decision: 新增明确的 form row seam，而不是直接大改 `SettingsInputRow`

`SettingsInputRow` 已被多个页面复用，直接改变它的布局可能造成大范围视觉回归。本 change 应优先新增或扩展更明确的 seam，命名可按实现风格微调：

```text
SettingsInlineTextFieldRow
  - 短文本右侧输入
  - 整行 tap 聚焦输入
  - 右侧区域限宽但不小于可用触区
  - 窄屏、大字体、长 label 时可降级为上下布局

SettingsNumericInlineFieldRow
  - 短数字右侧输入
  - digits-only/inputFormatters 支持
  - 适合 Port、保留版本数、过去天数

SettingsFormFieldRow
  - label 上方，filled/outlined field 下方
  - 稳定 padding 和最小高度
  - 适合 URL、路径、密码、密钥

SettingsMultilineFieldRow
  - label 上方，多行 field 下方
  - minLines/maxLines、helper/error text

SettingsLongValueRow
  - value maxWidth + ellipsis
  - 可选复制/chevron/action
```

Alternatives considered:

- 直接把 `SettingsInputRow` 全部改成 filled field：会影响 AI proxy、location、image bed、shortcut、server settings 等所有既有页面，视觉变化面过大。
- 让每个页面自己决定 `Row` / `Column`：短期快，但会继续扩散页面私有排版。
- 仅修 WebDAV 私有 `_InputRow`：能解决眼前问题，但不会解决同类字段在 AI proxy、image bed、Memoflow Bridge 中的重复问题。

### Decision: WebDAV 作为第一批验收页面

WebDAV 是最集中暴露问题的页面，适合作为首批验收基准：

```text
基本设置
  服务器地址     -> SettingsFormFieldRow
  用户名         -> SettingsInlineTextFieldRow
  密码           -> SettingsFormFieldRow + suffix visibility action

认证设置
  认证方式       -> SettingsNavigationRow / SettingsValueRow + picker

高级安全
  忽略 TLS 错误  -> SettingsToggleRow
  根路径         -> SettingsFormFieldRow

备份设置
  备份方式/计划  -> value row + picker
  保留版本数     -> SettingsNumericInlineFieldRow
```

实现必须保持 `normalizeWebDavRootPath`、auth mode、backup schedule、encryption、restore、sync、backup service behavior 不变。

### Decision: Settings-adjacent reminder pages 纳入本 change

`features/reminders` 不在 `features/settings` 目录下，但 `ReminderSettingsScreen` 和相关编辑页是从设置的功能组件入口打开的配置 surface。用户感知上它们属于设置体验的一部分。因此本 change 应把它们作为 settings-adjacent surfaces 处理：

- `ReminderSettingsScreen` 的 `_ToggleCard`、`_Group`、`_SelectRow`、`_ActionRow`、`_ToggleRow` 应收敛到 settings/task section 和 settings semantic rows。
- `MemoReminderEditorScreen` 的 raw `showDatePicker` / `showTimePicker` 应通过 settings/platform date/time picker seam 呈现。
- `CustomNotificationScreen` 的 `_InputCard` 应改为 settings form field / multiline field；预览卡可以保留领域语义，但圆角、阴影、字号应由 settings tokens 控制。

### Decision: Date/time picker 需要 settings-owned presentation seam

Raw `showDatePicker` / `showTimePicker` 在 Material 平台可用，但放在 Apple mobile 设置流中会显得突兀。实现应新增或复用 platform/settings picker seam，例如：

```text
showSettingsDatePicker
showSettingsTimePicker
showSettingsDateTimePicker
```

这些 seam 只承载 presentation 和 selected value，不拥有 reminder 业务逻辑。`MemoReminderEditorScreen`、勿扰时间、日期范围等调用方继续负责 validation 和 provider/service mutation。

### Decision: Guardrail 从“禁止高风险控件”扩展到“禁止高风险表单排版”

现有 `settings_ui_drift_guardrail_test.dart` 已能阻止很多 raw Material 控件回流。此 change 应增加更细的目标文件检查，例如：

- 目标文件不得新增裸 `PlatformTextField` + `InputBorder.none` 作为设置表单输入，除非 documented exception。
- 目标文件不得使用未限宽的 `trailing: Row(... Text(value) ...)` 展示长值。
- Reminder settings-adjacent 目标文件不得继续使用 raw `showDatePicker` / `showTimePicker`、`OutlinedButton.styleFrom` 或自定义 22px 阴影设置卡片。
- `platform/widgets/*` 不得导入 `features/*`、`state/*`、`application/*`、`data/*`。

## Risks / Trade-offs

- [Risk] 新增多个 form row seam 会扩大 `settings_ui.dart` 体量。→ Mitigation: 只抽通用字段排版和触区逻辑，不把页面业务状态或 provider mutation 放入 seam。
- [Risk] 用户名、Host 等右侧 inline 输入在窄屏或大字体下可能拥挤。→ Mitigation: inline seam 必须支持阈值降级到上下布局，并对 value 区域设置最小触区。
- [Risk] 直接改 `SettingsInputRow` 可能造成大量页面视觉变化。→ Mitigation: 首批新增明确 seam，再迁移目标页面；旧 row 可后续逐步淘汰。
- [Risk] Reminder 页面在 `features/reminders`，直接依赖 `features/settings/settings_ui.dart` 可能加深 feature-to-feature dependency。→ Mitigation: 当前已有 `MemoReminderEditorScreen` 使用 settings seam；本 change 应记录为 settings-adjacent 例外，并优先把可复用基础移到更稳定 platform/settings seam，避免 state/application/core 向 features 反向依赖。
- [Risk] 日期/时间 picker 的平台表现可能需要截图复核。→ Mitigation: 先提供 seam 和 focused tests；必要时将 iOS visual adjustment 留为后续 polish，但调用方不再直接使用 raw Material picker。
- [Risk] 目标页面较多，一次全部迁移容易引入视觉回归。→ Mitigation: 按 WebDAV、网络/账号字段、reminder 三批实施，每批跑 focused tests 和人工复核。

## Migration Plan

1. 建立 settings form ergonomics seam 和 focused tests，先覆盖 inline text、numeric inline、full-width form field、multiline field、long value、date/time picker 的核心行为。
2. 迁移 WebDAV，作为字段排版验收基准。
3. 迁移 AI proxy、image bed、location key、Memoflow Bridge、shortcut/server numeric fields 等设置字段。
4. 迁移 reminder settings-adjacent surfaces：reminder settings、memo reminder editor、自定义通知。
5. 扩展 guardrail，阻止目标文件回退到小触区、未限宽长值、raw date/time picker、页面私有卡片/按钮样式。
6. 运行 focused tests、`flutter analyze`，并按风险运行相关 settings/reminder widget tests。

Rollback: 如果某个新增 row seam 视觉不符合预期，应保留 seam API 并调整平台呈现，不应回退到页面私有 `PlatformTextField` + `InputBorder.none` 作为长期方案。若 reminder 页面迁移风险过大，可先完成 WebDAV 和 settings fields，保留 reminder 批次为单独任务，但 spec 中继续记录 settings-adjacent 目标。

## Open Questions

- `SettingsInputRow` 是否在本 change 末尾标记为 legacy/lightweight，还是保留为通用字段入口并内部按参数选择 layout。
- Reminder settings-adjacent 是否需要独立 `SettingsTaskPage` / `SettingsTaskSection` seam，还是直接复用 `SettingsPage` / `SettingsSection`。
- iOS date/time picker 是否优先使用 `CupertinoDatePicker` bottom sheet，还是先通过 existing platform picker/dialog seam 封装。
