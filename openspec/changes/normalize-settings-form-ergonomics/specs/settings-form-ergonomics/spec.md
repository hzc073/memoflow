## ADDED Requirements

### Requirement: Settings fields SHALL choose layout by field semantics

设置页和 settings-adjacent 配置页 SHALL 按字段内容语义选择输入排版，而不是把所有输入都渲染为同一种 `subtitle` text field。短文本、短数字、长文本、密钥/密码、多行文本、长值展示、日期/时间选择 SHALL 使用对应的 settings semantic seam。

#### Scenario: Short text field renders inline

- **WHEN** 设置页渲染用户名、Host、Pair code、快捷方式名称等短文本字段
- **THEN** 字段 SHALL 支持左侧 label + 右侧 inline 输入排版
- **AND** 整行或明确的右侧输入区域 SHALL 可用于聚焦输入
- **AND** 在窄屏、长 label 或大字体场景下 SHALL 可降级为上下完整输入排版

#### Scenario: Short numeric field renders compactly

- **WHEN** 设置页渲染 Port、保留版本数、过去多少天、策略 ID 等短数字字段
- **THEN** 字段 SHALL 使用短数字输入 seam
- **AND** 输入区域 SHALL 有稳定最小触区
- **AND** 调用方现有 numeric keyboard、input formatters、validation callback SHALL 保持可用

#### Scenario: Long text field renders full width

- **WHEN** 设置页渲染服务器 URL、API URL、测试 URL、根路径、本地路径或其他长文本字段
- **THEN** 字段 SHALL 使用 label 上方 + 完整宽度输入框下方的排版
- **AND** field SHALL 使用稳定 padding、可见 field surface 或等价视觉边界
- **AND** 字段值 SHALL NOT 因右侧空间不足撑破设置行容器

#### Scenario: Secret field renders with secure affordance

- **WHEN** 设置页渲染 password、API Key、Security Key、access token 或其他敏感字段
- **THEN** 字段 SHALL 使用完整输入或 secure field seam
- **AND** 需要显示/隐藏、复制或清除操作时 SHALL 通过 suffix action 或 settings action seam 呈现
- **AND** 字段排版 SHALL NOT 依赖页面私有 `PlatformTextField` + `InputBorder.none` 小触区实现

#### Scenario: Multiline field renders as form surface

- **WHEN** 设置页渲染 AI 个人资料、反馈备注、通知正文或其他多行文本
- **THEN** 字段 SHALL 使用多行表单 seam
- **AND** minLines/maxLines、helper text、error text 和 hint SHALL 保持可表达
- **AND** 输入区域 SHALL 有明确边界和稳定 padding

### Requirement: Settings form inputs SHALL maintain usable touch targets and typography

设置表单输入 SHALL 在 Apple mobile、Android 和 desktop settings surfaces 中保持可点击/可选区域稳定，且字号层级 SHALL 与 settings row title、description 和 value 文本一致。

#### Scenario: Apple mobile text field has nonzero padding

- **WHEN** iPhone/iPadOS 设置页渲染目标表单输入
- **THEN** 输入 field SHALL NOT 通过 `InputBorder.none` 导致 `CupertinoTextField` 使用 zero padding 作为主要触区
- **AND** 输入 field SHALL 提供稳定 vertical padding 或等价最小高度

#### Scenario: Settings typography stays consistent

- **WHEN** 设置页、settings dialog 或 settings-adjacent reminder surface 渲染字段 label、value、helper、description
- **THEN** 主 label SHALL 使用 settings row title 层级或等价 14px 左右层级
- **AND** helper、section label、secondary description SHALL 使用 settings description 层级或等价 12px 左右层级
- **AND** 文本 SHALL NOT 继承导致黄色下划线或不一致 decoration 的默认样式

#### Scenario: Inline input remains usable

- **WHEN** inline 输入字段右侧可用宽度不足以容纳当前值和可点击区域
- **THEN** seam SHALL 约束、截断或切换为上下布局
- **AND** 用户 SHALL 仍能通过稳定区域进入编辑状态

### Requirement: Long values SHALL be constrained and readable

设置页中 URL、路径、导出位置、Webhook URL、备份状态路径等长值展示 SHALL 统一限宽、截断或转为二级描述，避免撑破设置容器。

#### Scenario: Long trailing value is constrained

- **WHEN** 设置行在右侧展示路径、URL 或长状态值
- **THEN** 右侧 value SHALL 有 maxWidth 约束
- **AND** 文本 SHALL 使用 single-line ellipsis 或 equivalent readable fallback
- **AND** chevron、copy icon、delete icon 等 trailing controls SHALL 保持可见

#### Scenario: Long description uses secondary area

- **WHEN** 长值不适合右侧展示
- **THEN** 设置行 SHALL 使用 subtitle/description、多行详情、copy action 或二级页面展示
- **AND** 主 label 和交互 affordance SHALL NOT 被长值挤出视图

### Requirement: WebDAV settings SHALL use ergonomic field layouts

WebDAV 连接和备份设置 SHALL 作为首批字段排版验收页面，使用 settings form ergonomics seam 替换页面私有 `_InputRow`、`_InlineInputRow` 和未约束 `_SelectRow` 的高风险排版。

#### Scenario: WebDAV basic fields render by content type

- **WHEN** WebDAV 连接设置渲染服务器地址、用户名和密码
- **THEN** 服务器地址 SHALL 使用完整宽度长文本输入排版
- **AND** 用户名 SHALL 使用右侧 inline 短文本输入或窄屏 fallback
- **AND** 密码 SHALL 使用 secure/full-width 输入排版并保留显示/隐藏 action

#### Scenario: WebDAV advanced fields render safely

- **WHEN** WebDAV 高级安全设置渲染认证方式、忽略 TLS、根路径
- **THEN** 认证方式 SHALL 使用 value row + picker 或 equivalent settings choice seam
- **AND** 忽略 TLS SHALL 使用 settings toggle row
- **AND** 根路径 SHALL 使用完整宽度长文本输入排版

#### Scenario: WebDAV backup fields render safely

- **WHEN** WebDAV 备份设置渲染备份方式、备份计划、保留版本数和备份状态长值
- **THEN** 备份方式和备份计划 SHALL 使用 value row + picker 或 equivalent choice seam
- **AND** 保留版本数 SHALL 使用短数字输入 seam
- **AND** 备份路径、错误路径或状态路径 SHALL 受长值约束保护

#### Scenario: WebDAV behavior is preserved

- **WHEN** WebDAV fields are migrated to ergonomic seams
- **THEN** auth mode、root path normalization、ignore TLS setting、backup schedule、encryption mode、restore、sync、backup service behavior SHALL remain unchanged
- **AND** WebDAV protocol request/response behavior SHALL NOT be modified

### Requirement: Settings network and account fields SHALL follow the same ergonomics

AI proxy、image bed、location provider key、Memoflow Bridge、shortcut、server settings 等设置页 SHALL 复用相同字段排版语义，避免同类字段在不同页面出现不同触区和排版。

#### Scenario: AI proxy fields render ergonomically

- **WHEN** AI proxy settings 渲染 protocol、Host、Port、username、password、test URL
- **THEN** protocol SHALL 使用 settings picker row
- **AND** Host 和 username SHALL 使用短文本 inline 输入
- **AND** Port SHALL 使用短数字输入
- **AND** password 和 test URL SHALL 使用完整输入排版

#### Scenario: Image bed fields render ergonomically

- **WHEN** image bed settings 渲染 API URL、email、password、strategy ID
- **THEN** API URL SHALL 使用完整长文本输入
- **AND** email SHALL 使用短文本 inline 输入或窄屏 fallback
- **AND** password SHALL 使用 secure/full-width 输入
- **AND** strategy ID SHALL 使用短数字输入

#### Scenario: Provider key fields render full width

- **WHEN** location settings 渲染 AMap Web API Key、AMap Security Key、Baidu AK 或 Google API Key
- **THEN** these key fields SHALL use full-width secret/key input layout
- **AND** they SHALL NOT be forced into narrow trailing input layout

#### Scenario: Bridge and shortcut numeric fields render compactly

- **WHEN** Memoflow Bridge、shortcut editor 或 server settings 渲染 Host、Port、Pair code、过去天数或数字单位字段
- **THEN** short Host/Pair code/name values SHALL use inline text layout when space allows
- **AND** Port、过去天数和数字单位 SHALL use numeric inline layout

### Requirement: Reminder settings-adjacent surfaces SHALL align with settings ergonomics

从设置入口进入的 reminder 配置 surface SHALL 使用 settings/task semantics 统一排版、动作、picker 和输入表面，而不是继续使用页面私有大圆角阴影卡片和 raw Material controls。

#### Scenario: Reminder settings rows use settings semantics

- **WHEN** reminder settings 渲染通知标题、通知正文、测试提醒、铃声、勿扰时间、开关项
- **THEN** selectable values SHALL use settings value/navigation rows with constrained values
- **AND** actions SHALL use `SettingsAction`、`PlatformPrimaryAction` 或 equivalent settings action seam
- **AND** toggles SHALL use settings/platform toggle seam

#### Scenario: Reminder editor uses platform picker seam

- **WHEN** memo reminder editor 选择日期、时间或提醒时间列表
- **THEN** date/time selection SHALL use settings/platform picker seam
- **AND** raw `showDatePicker` and raw `showTimePicker` SHALL NOT remain in the migrated reminder editor flow
- **AND** existing reminder validation and mutation behavior SHALL remain unchanged

#### Scenario: Custom notification form uses settings fields

- **WHEN** custom notification page 渲染标题和正文输入
- **THEN** 标题 SHALL use inline or full-width short text field layout
- **AND** 正文 SHALL use multiline field layout
- **AND** preview card MAY remain domain-specific but SHALL use settings tokens for radius, typography, border/shadow decisions

### Requirement: Settings date and time choices SHALL use platform presentation seams

设置页和 settings-adjacent 配置页中的日期、时间、日期时间或日期范围选择 SHALL 使用 settings/platform presentation seam，而不是在目标页面中直接调用 raw Material picker。

#### Scenario: Date time picker opens from settings flow

- **WHEN** migrated settings or reminder surface asks the user to choose date, time, date-time, or date range
- **THEN** it SHALL call a settings/platform picker seam
- **AND** Apple mobile presentation SHALL be Apple-appropriate or explicitly provided by the platform seam
- **AND** selected value SHALL return to the existing callback or mutation path

#### Scenario: Picker behavior remains owned by caller

- **WHEN** a page uses settings date/time picker seam
- **THEN** the seam SHALL NOT own provider mutation, reminder scheduling, WebDAV behavior, or repository writes
- **AND** caller validation such as past-time rejection SHALL remain in the page or existing service owner

### Requirement: Settings form ergonomics SHALL be guarded and tested

The migration SHALL include focused tests and guardrails so目标页面不会回退到小触区输入、未约束长值、raw date/time picker 或页面私有设置卡片体系。

#### Scenario: Form seam focused tests run

- **WHEN** focused settings UI tests run
- **THEN** inline text, numeric inline, full-width form field, multiline field, long value row, and settings date/time picker seams SHALL have widget coverage
- **AND** Apple mobile tests SHALL assert no Flutter framework exception is thrown

#### Scenario: Target page smoke tests run

- **WHEN** WebDAV and reminder settings focused tests run
- **THEN** tests SHALL cover representative migrated fields and picker flows
- **AND** tests SHALL verify long values do not overflow their row constraints when practical in widget tests

#### Scenario: Drift guardrail covers high-risk patterns

- **WHEN** architecture or settings UI drift guardrail tests run
- **THEN** migrated target files SHALL fail or warn if they introduce naked `PlatformTextField` + `InputBorder.none` for settings form fields, unconstrained trailing long values, raw `showDatePicker`, raw `showTimePicker`, page-level `OutlinedButton.styleFrom` settings actions, or private 22px shadow settings cards without documented exception

#### Scenario: Boundary guardrail is preserved

- **WHEN** settings/platform form ergonomics code is added or changed
- **THEN** `platform/widgets/*`, `state`, `application`, and `core` layers SHALL NOT add new imports from `features/settings` or `features/reminders`
- **AND** shared UI behavior SHALL live in settings/platform seams rather than page-private reusable widgets
- **AND** public repository code SHALL NOT add subscription, billing, entitlement, receipt, paywall, StoreKit, product ID, price, private overlay, or `AccessDecision.source` business branching logic
