## Context

MemoFlow 顶层目前由 `MaterialApp` 承载 theme、localization、route 和 `MediaQuery` 包装。Apple 平台已经通过 `PlatformPage`、`buildPlatformPageRoute`、`PlatformListSection`、`PlatformSwitch`、`AppleMobileShell` / `AppleTabletShell` 等 seam 获得部分 Cupertino chrome，但全局字体链路仍然是：

```text
DevicePreferences
  ├─ fontSize ───────────────▶ app.dart builder 覆盖 MediaQuery.textScaler
  ├─ lineHeight ─────────────▶ app_theme.dart 全局 TextTheme height
  └─ fontFamily/fontFile ───▶ app_theme.dart 全局 TextTheme fontFamily
                                  ▲
                                  │
                       iOS 也会走同一条路径
```

同时 `SystemFonts.listFonts()` 对 iOS 没有可用分支，settings 字体选择在 iOS 上只能展示“系统默认 + 未找到系统字体”。跨设备迁移还会携带 `fontFamily` / `fontFile`，这使 iOS 可能继承来自 Windows/macOS 的字体名，形成不可预测 fallback。

本变更触及 `app.dart` composition root、`core/app_theme.dart`、`platform/` UI seam 和 settings pilot area。依赖方向应保持：

```text
app.dart
  ├── reads state/preferences
  └── calls stable core/platform typography policy

core or platform typography policy
  └── depends only on Flutter platform primitives and preference model types

features/settings
  └── renders semantic settings rows and asks platform/system-font capability

platform/
  └── MUST NOT import features/state/application/data
```

Before: `app.dart` 和 `app_theme.dart` 直接把用户字体、行高、字号偏好应用到所有平台；settings page 直接展示字体选择入口；Apple shell 只设置 `CupertinoThemeData.brightness` 和 `primaryColor`。

After: effective typography 和 iOS 字体入口能力由集中 policy/seam 解析；feature pages 不新增局部 iOS 分支；platform adapter dependency direction 通过既有或新增 guardrail 保持稳定。

## Goals / Non-Goals

**Goals:**

- 让 iPhone/iPadOS 默认使用系统字体，不被跨平台同步或迁移来的 `fontFamily` / `fontFile` 影响。
- 保留 iOS 系统 text scaling 语义，并将应用的 small/standard/large 偏好作为平台安全的附加策略，而不是直接替换系统 scaler。
- 避免把 reader-oriented line height 强制作用到 Apple page chrome、list rows、buttons、navigation text 等高感知 UI。
- 让 iOS 设置页的字体入口不再展示无效系统字体列表，同时保留 Android、Windows、macOS、Linux 的现有字体选择能力。
- 把平台 typography/surface 规则沉到 stable seam 或 settings/platform seam，减少后续 feature-local `TargetPlatform.iOS` 分支。
- 增加 focused tests 和 dependency guardrail，使 touched area 在 `evolve_modularity` 阶段结构不退化。

**Non-Goals:**

- 不引入内置应用字体，不处理字体授权、字体子集化、包体增长或多字重打包。
- 不把 `MaterialApp` 全量替换为 `CupertinoApp`。
- 不重做所有 iOS 页面视觉、memo card 设计、settings 全量迁移或 reader typography 系统。
- 不修改 API adapter、request/response model、server compatibility、WebDAV sync protocol 或数据库 schema。
- 不添加任何商业、订阅、付费、StoreKit、entitlement、receipt 或 private overlay 逻辑。

## Decisions

### Decision: 新增或集中 `EffectiveAppTypography` policy

实现阶段应把字体 family、font fallback、line-height scope 和 text-scale composition 的决策集中到 `core` 或 `platform` 的稳定 helper，例如 `core/app_typography_policy.dart` 或等效现有 theme helper，而不是在 `app.dart`、settings page 和 Apple shell 中分别判断 iOS。

该 policy 可以接收 `TargetPlatform` / `PlatformExperience`、`AppFontSize`、`AppLineHeight`、`fontFamily`、`fontFile` 和当前 `MediaQuery.textScaler`，输出：

```text
EffectiveAppTypography
  ├─ themeFontFamily
  ├─ themeFontFallback
  ├─ applyUiLineHeight
  ├─ contentLineHeight
  └─ effectiveTextScaler
```

Alternatives considered:

- 在 `app_theme.dart` 内直接加 `if TargetPlatform.iOS`：改动短，但会继续把平台经验、UI 行高、字体能力和 settings 行为散落到多个文件。
- 在 `AppleMobileShell` 内覆盖字体：只能影响 Cupertino subtree，不能修正 `MaterialApp.theme`、settings 字体入口或 `MediaQuery` 缩放。
- 引入内置字体：不能解决 Dynamic Type、line height 和 invalid font picker 问题，还会增加包体与授权复杂度。

### Decision: iOS effective font ignores persisted custom/system font selection

iOS/iPadOS 的全局 app chrome 应使用平台系统字体。`DevicePreferences.fontFamily` / `fontFile` 可继续保留用于其他平台和跨设备同步，但 iOS effective theme 不应应用这些字段。用户在 iOS 上看到的字体状态应是“系统默认”或等效文案，不应允许选择一个无法加载的系统字体。

Alternatives considered:

- 清空 iOS 上持久化的 `fontFamily`：会破坏同一份设置同步回桌面后的用户选择，且是数据行为变更。
- 尝试扫描 iOS 系统字体路径：iOS sandbox 下不可依赖，且用户体验仍不等价于真正的系统字体选择。
- 在 `pubspec.yaml` 打包一套品牌字体：这是另一个产品/品牌决策，不应作为修 bug 的第一步。

### Decision: 保留系统 text scaling，再叠加应用偏好

`app.dart` 目前直接 `media.copyWith(textScaler: TextScaler.linear(scale))`。实现阶段应改为平台安全的 composition：iOS 至少保留系统 `MediaQuery.textScalerOf(context)` 的效果，再叠加 app small/standard/large 偏好；非 iOS 平台应尽量保持现有行为，除非 tests 明确覆盖新的兼容行为。

Alternatives considered:

- iOS 完全忽略 app font size preference：最接近系统，但会让用户设置失效。
- 所有平台都组合系统 scaler：语义更统一，但可能扩大 Windows/Android/Web 的视觉变更范围。
- 继续覆盖系统 scaler：保留当前行为，但无法解决 iOS Dynamic Type 观感问题。

### Decision: UI chrome 与阅读内容的 line-height scope 分离

当前 `applyPreferencesToTheme` 对 `TextTheme` 的 body/title 样式统一应用 `lineHeightFor(prefs.lineHeight)`。实现阶段应避免 Apple UI chrome 强制使用 reader-oriented line height。第一版可以采用保守方案：iOS 全局 UI theme 不应用用户 line height，阅读器、memo 正文或明确内容区域继续使用已有 content line-height preference。

Alternatives considered:

- 继续全局应用 line height：简单但正是 UI chrome 看起来松散的原因之一。
- 马上重构所有正文/阅读文字入口：范围过大，容易影响 memo/collections/review 多个页面。
- 只调低 `classic` 值：会改变所有平台和所有内容文本，风险更高。

### Decision: settings 字体入口通过 semantic capability 呈现

`PreferencesSettingsScreen` 不应自己判断“iOS 没有字体”。实现阶段可以在 settings semantic seam、system-font provider helper 或 typography policy 中暴露 `canChooseSystemFonts` / `effectiveFontLabel` 之类的信息，让 settings row 选择隐藏、禁用或只显示系统默认。具体 UI 形态应通过已有 `SettingsValueRow` / `SettingsSection` 表达。

Alternatives considered:

- 在 `_selectFont` 里保留空列表提示：行为真实但体验误导，因为 iOS 上不是“暂时没找到”，而是当前不支持选择。
- 删除所有平台字体设置：破坏 Android/desktop 已有功能。
- 为 iOS 单独创建 preferences page：违反 platform adaptive UI 的共享页面树原则。

### Decision: settings value metadata 使用平台原生 row slot

截图验证后发现，iOS 设置页的异常大字主要来自右侧 value text 被塞进 `CupertinoListTile.trailing`。Flutter 的 Cupertino row 语义中，右侧说明文字应使用 `additionalInfo`，而 `trailing` 更适合 chevron、switch 或 icon。实现阶段应在 `PlatformListSectionRow` 或等效 settings/platform seam 暴露 value metadata slot，让 `SettingsValueRow` / `SettingsNavigationRow` 把 selected label、font label、mode label 等 value text 交给该 slot。

iPhone/iPadOS 上该 slot 应映射到 `CupertinoListTile.additionalInfo` 或等效受约束 metadata 区域，并保持 disclosure icon 作为 trailing control。Android、Windows、macOS、Linux 和 web 的 Material row 应继续组合为现有 trailing presentation，避免因为 Apple mobile 修复改变 Android 视觉和交互。

Alternatives considered:

- 只给 `SettingsValueRow` 的 value `Text` 固定 `fontSize`：可以缓解截图，但会绕开 Dynamic Type 和平台 row 语义，不是根本修复。
- 在 `PreferencesSettingsScreen` 内对每个 row 写 iOS 分支：会把平台规则散落到 feature page，违反本 change 的 centralized seam 目标。
- 全局关闭 iOS `MediaQuery.textScaler`：会回退到旧问题，破坏系统辅助功能字号语义。

### Decision: guardrail 聚焦 dependency direction 和商业边界

本变更不应引入 `platform -> features/state/application/data`。如新增 `platform/` typography/surface policy 或修改 Apple shell，应扩展现有 platform UI guardrail 或新增 focused architecture test。商业边界检查应继续覆盖 Apple/settings/public shell touched files。

Alternatives considered:

- 只靠人工 review：当前处于 `evolve_modularity`，touched area 应留下自动化防线。
- 把 policy 放在 feature settings 下：会让 `app.dart` 或 core theme 反向依赖 feature code，违反稳定层方向。

## Risks / Trade-offs

- [Risk] iOS 用户之前从桌面同步来的字体偏好在 iPhone 上不再生效。→ Mitigation: 不删除持久化字段，只改变 iOS effective theme；返回桌面仍可使用原偏好。
- [Risk] 组合系统 text scaler 后部分 UI 可能变高或溢出。→ Mitigation: 增加 iPhone widget tests 覆盖 settings、onboarding 或 representative shell，并优先保持 bounded layout。
- [Risk] 不引入内置字体可能无法满足未来品牌一致性。→ Mitigation: 明确作为 Non-goal；若视觉验收仍需要品牌字体，后续单独提案评估授权、包体和字重。
- [Risk] 分离 UI chrome line height 与正文 line height 可能暴露某些页面直接依赖全局 theme 的正文样式。→ Mitigation: 第一版只对 iOS global UI chrome 收敛，并保留阅读器/内容区域既有显式 preferences。
- [Risk] settings 字体入口隐藏或禁用后用户可能不知道字体仍可在其他平台设置。→ Mitigation: 文案使用“系统默认”或等效说明，不把 iOS 空列表表述成错误。

## Migration Plan

1. 增加 focused policy tests，锁定 iOS effective font、non-iOS existing font behavior、text scaler composition 和 line-height scope。
2. 实现 typography/platform policy，并让 `app.dart` / `app_theme.dart` 使用该 policy。
3. 调整 settings 字体入口读取同一 policy 或 capability helper，避免 iOS 打开无效字体列表。
4. 调整 settings/platform row seam，把 value metadata 从 unconstrained trailing control 移到平台原生 metadata slot，并补充 iPhone 大字号回归测试。
5. 如需要，补充 Apple shell `CupertinoThemeData.textTheme` 映射，但只使用 policy 输出，不在 shell 中重新解析 preferences。
6. 增加或更新 platform dependency guardrail 和 public/commercial leakage checks。
7. 运行 focused tests、`flutter analyze`，并在变更完成前按项目要求运行 `flutter test`。

Rollback: 可先回退 `app.dart` 的 text scaler composition 或 settings 字体入口调整；policy helper 可保留但恢复旧调用路径。由于不改持久化数据和 schema，回滚不需要数据迁移。

## Open Questions

- iOS 上字体设置入口应隐藏、禁用，还是保留为只读“系统默认”？设计倾向只读或隐藏；实现阶段可根据现有 settings density 选择更小改动。
- App font size preference 在 iOS 上应采用 `system * appScale` 还是只在 `standard` 时完全等于系统 scaler？设计倾向 `system * appScale`，但需要用测试确认布局影响。
- UI chrome line height 的第一版是否只对 iOS 生效，还是为所有 Apple platforms 包含 macOS？本 change 聚焦 iOS/iPadOS；macOS 可保持现状或只在无风险处复用 policy。
