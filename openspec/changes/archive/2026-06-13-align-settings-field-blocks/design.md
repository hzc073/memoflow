## Context

这次问题不是单个页面的配色问题，而是 settings form seam 的层级问题。旧的完整输入字段大致是：

```text
SettingsSection
  └─ PlatformListSectionRow
       ├─ title: SettingsRowTitle
       └─ subtitle:
            └─ filled PlatformTextField
```

`PlatformListSectionRow` 在 Apple mobile、Android 和 desktop 上都有自己的 row padding、subtitle 排版和 list density；filled input 又有自己的 border、fill、content padding。两套布局叠加后，长输入灰框会在部分页面里看起来没有和外层 section 对齐，WebDAV“服务器连接”只是最明显的例子。

已经完成的 `normalize-settings-form-ergonomics` 解决了“字段语义应该选择 inline / numeric / full-width / multiline”的问题，但没有完全解决 full-width field surface 和外层 section 的视觉网格一致性。本 change 是它的 follow-up polish：把 WebDAV 中验证过的 field block 方向沉淀到 settings seam，并把其他已迁移设置页拉到同一规则上。

依赖方向保持：

```text
features/settings 页面
        │ label/controller/callback
        ▼
features/settings/settings_ui.dart
        │ 统一 field block 视觉、padding、helper/error、theme token
        ▼
platform/widgets/PlatformTextField
        │ 平台文本输入实现
        ▼
Flutter widgets
```

Before: 多个 settings 页面通过 `SettingsFormFieldRow` / `SettingsMultilineFieldRow` 间接依赖 `PlatformListSectionRow` subtitle 布局表达完整输入字段。

After: 完整输入字段由 settings-owned field block seam 表达，页面只传入 controller、hint、suffix action、callbacks。不会新增 `state -> features`、`application -> features`、`core -> features` 或 `platform -> features` 依赖。

当前架构阶段为 `evolve_modularity`。触及的热点是 `features/settings` 共享 UI seam；模块化改进是把重复视觉规则收敛进 `settings_ui.dart` 并用 guardrail 防止页面私有 form field 回流。

## Goals / Non-Goals

**Goals:**

- 让完整宽度输入字段的灰色 filled surface 与 settings section 形成统一视觉网格。
- 将 `SettingsFormFieldRow` / `SettingsMultilineFieldRow` 或等价入口统一委托到 field block seam，避免继续依赖 list row subtitle 作为主要输入布局。
- 保留 `SettingsInlineTextFieldRow` / `SettingsNumericInlineFieldRow` 的短字段语义；仅让窄屏 fallback 使用对齐后的完整 field block。
- 迁移高感知页面中的长输入、密码/密钥和多行输入字段：AI proxy、image bed、location provider key、自定义通知、AI user profile、export logs 等。
- 保持颜色、边框、helper/error 文本、suffix icon 和 focus border 来自现有 `settingsPageTokens(context)` / `Theme.of(context).colorScheme`。
- 更新 focused tests 和 drift guardrail，防止 migrated settings files 回退到 subtitle-based filled input 或 page-local field card。

**Non-Goals:**

- 不重做设置页配色体系，不修改 `ThemeData`、`ColorScheme`、`MemoFlowPalette`、`AppColors`、ThemeExtension 或主题 token。
- 不改变字段业务含义、provider 写入、controller 绑定、normalization、validation、测试连接、同步、备份、提醒调度、API adapter 或数据库 schema。
- 不把所有 inline 短字段强制改成 full-width。Host、Port、Pair code、短名称等仍保留 inline/numeric 表达。
- 不处理设置首页 hierarchy、profile card、shortcut tile 或其他非表单字段层级。
- 不新增商业/private hooks、subscription、billing、entitlement、paywall、StoreKit 或 paid-feature 逻辑。

## Decisions

### Decision 1: field block 是 settings seam，不是页面私有组件

完整输入字段应由 `settings_ui.dart` 里的 `SettingsFieldBlock` 或等价内部实现提供，页面不应复制 `_FieldBlock`、`_InputCard`、`Container + TextField` 等局部实现。

Rationale: 这类错位来自共享 seam 的布局选择。如果只修页面，后续页面仍会重复出错；把 field block 放在 settings seam 可以让 AI proxy、image bed、location、reminder-adjacent surfaces 共享同一套网格。

Alternative considered: 只把 WebDAV 保持局部 `_ConnectionSection + SettingsFieldBlock`。这能解决截图问题，但无法覆盖用户指出的“设置页不止一个地方”。

### Decision 2: `SettingsFormFieldRow` / `SettingsMultilineFieldRow` 应复用 field block

实现时优先让现有调用点继续使用 `SettingsFormFieldRow` 和 `SettingsMultilineFieldRow`，由这些 seam 内部委托到 field block，而不是要求所有页面批量改 API。必要时保留显式 `SettingsFieldBlock` 给特殊页面使用。

Rationale: 调用点较多，改内部实现比逐页替换更稳，也减少业务页面 diff。API 兼容还能降低测试负担。

Alternative considered: 让所有页面显式替换为 `SettingsFieldBlock`。该方案表达清晰，但机械改动更大，且容易漏掉 `SettingsInlineTextFieldRow` 的窄屏 fallback。

### Decision 3: 保留 inline 字段语义，修正 fallback

`SettingsInlineTextFieldRow` 和 `SettingsNumericInlineFieldRow` 仍用于短文本/数字。它们在窄屏、长 label 或大字体下 fallback 到完整输入时，应使用对齐后的 full-width field block，而不是旧 subtitle form row。

Rationale: inline 短字段在设置页是有效信息密度；问题不在 inline 本身，而在 fallback 和长/敏感字段使用了不适合的 subtitle layout。

### Decision 4: 迁移范围按高感知字段排序

第一批应覆盖：

| 页面 | 字段 | 处理 |
| --- | --- | --- |
| AI proxy | password、test URL | full-width field block |
| Image bed | API URL、password | full-width field block |
| Location settings | AMap/Baidu/Google key | full-width field block |
| Custom notification | body | multiline field block |
| AI user profile | profile text | multiline field block |
| Export logs | notes | multiline field block |

Rationale: 这些字段最接近 WebDAV 的错位场景：长文本、密钥、密码、多行输入，且都位于 settings migrated files。

### Decision 5: 颜色和主题只做派生，不引入新体系

field block 的 fill、border、focused border、hint、label、helper、error 都使用现有 settings tokens 或 `ColorScheme`。允许调整 padding、radius、alpha、min height，但不得新增固定 hex 或修改全局 theme。

Rationale: 用户明确要保留现有 App 主题颜色体系。这个 change 是布局层级修正，不是主题重设计。

### Decision 6: guardrail 明确识别高风险回退

`settings_ui_drift_guardrail_test.dart` 应继续要求目标页面使用 settings form seams，并防止目标文件新增裸 `PlatformTextField(`、`InputBorder.none`、page-local `TextField`、page-local card field wrapper 或 raw button styling。若某个页面确有例外，应在 guardrail 中显式说明。

Rationale: 这是 `evolve_modularity` 下的触点改进：把视觉规则从页面收敛到 seam，并让自动检查防止退化。

## Risks / Trade-offs

- [Risk] 直接改变 `SettingsFormFieldRow` 内部布局会影响多个页面视觉。→ Mitigation: 先聚焦 settings migrated target files，保留相同 public constructor 和参数，运行 focused widget tests、settings UI drift guardrail、`flutter analyze` 和必要截图/人工复核。
- [Risk] 桌面端表单变得比以前更高，影响密集设置页。→ Mitigation: field block 可按平台/constraints 保持适度 vertical padding；desktop 不需要复刻移动端大间距。
- [Risk] `SettingsInlineTextFieldRow` fallback 后高度变化。→ Mitigation: fallback 只在窄屏、大字体或长 label 场景发生，本来就需要更多空间来避免挤压。
- [Risk] 多行输入使用统一 field block 后预览/说明区域显得更重。→ Mitigation: 多行字段保留 min/max lines 和 helper text，section spacing 不额外扩大。
- [Risk] 误改业务页面 callback。→ Mitigation: 页面迁移只替换 presentation seam，controller、onChanged、onEditingComplete、suffix action、validation 和 provider mutation 原样保留。

## Migration Plan

1. 复查 `SettingsFormFieldRow`、`SettingsMultilineFieldRow`、`SettingsInlineTextFieldRow` fallback 和 `SettingsFieldBlock` 当前实现，确认参数覆盖完整。
2. 将 full-width form row 和 multiline row 统一委托到 field block seam，保留现有 constructor API。
3. 迁移或确认高感知页面字段使用统一 seam，不引入页面私有字段 wrapper。
4. 更新 settings UI drift guardrail 和 focused widget tests。
5. 运行 `flutter analyze`、relevant focused tests、settings UI drift guardrail、modularity guardrail，必要时运行 full `flutter test`。

Rollback: 如果统一 field block 在某个页面出现明显布局回归，优先调整 seam 的 platform/density 参数；不要回退到页面私有 `PlatformTextField + InputBorder.none`。

## Open Questions

- `SettingsFieldBlock` 是否应保持 public settings seam，还是作为 `SettingsFormFieldRow` 的内部实现并减少直接调用点。
- desktop dense settings 是否需要独立 padding 参数，还是现有统一 padding 足够。
- 自定义通知预览卡是否也需要后续跟随 settings surface tokens 调整，还是本 change 只处理输入字段。
