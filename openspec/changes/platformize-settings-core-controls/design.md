## Context

当前设置页平台化已经有基础：

```text
SettingsPage
  -> PlatformPage
     -> iOS/iPadOS: CupertinoPageScaffold
     -> Android/Desktop: Scaffold

SettingsSection
  -> PlatformListSection
     -> iOS/iPadOS: CupertinoListSection.insetGrouped
     -> Desktop/Android: Material-backed section
```

这个结构正确地让 Apple mobile 设置页接近系统设置，但也暴露了一个前提：`CupertinoListSection` 不提供 `Material` ancestor。凡是子页面在 `SettingsSection` 内直接使用 `ChoiceChip`、`FilterChip`、`RadioListTile`、`CheckboxListTile`、`FilledButton` 等 Material-only 控件，都可能在 iPhone/iPadOS 触发 framework exception。

`platformize-settings-menu-row-picker` 已经把 `SettingsMenuRow<T>` 从 inline `DropdownButton<T>` 改为 platform picker row，但这只是 enum dropdown 的一类。新日志显示 `LocationSettingsScreen` 的 `ChoiceChip` 仍然会崩，所以需要先补齐通用 settings control seam。

## Goals / Non-Goals

**Goals:**

- 让 settings 常用控件通过语义化 settings/platform seam 表达，而不是页面直接选择 Material-only widget。
- 在 iPhone/iPadOS 的 `SettingsPage` / `SettingsSection` 内，核心设置控件可直接渲染且不需要外部 `Material` ancestor。
- 保持 Android、Windows、Linux、macOS 现有交互尽量稳定；Material 平台可以继续使用 Material widget，但由 seam 统一承载。
- 为后续 `platformize-settings-subpages` 提供可复用控件，避免每个页面复制 iOS 特判。
- 增加 focused iOS tests 覆盖核心控件。

**Non-Goals:**

- 不在本 change 批量迁移 `LocationSettingsScreen`、`WebDavSyncScreen`、AI 向导、模板、快捷键等具体页面。
- 不重新设计完整 settings 信息架构。
- 不替换 app 全局所有 `TextField`、`showDialog` 或 button，只处理 settings/platform 需要复用的控件 seam。
- 不修改 API、数据库、WebDAV、同步协议、本地库路径或商业/private seam。

## Decisions

### Decision: 先补齐 settings-owned semantic controls

实现阶段应优先在 `settings_ui.dart` 或 platform widgets 中提供以下语义控件：

```text
SettingsOptionChoiceRow / SettingsOptionChipGroup
  label + options + selected + onChanged

SettingsSingleChoiceRow / SettingsSingleChoiceList
  options + selected + onChanged

SettingsMultiChoiceRow / SettingsMultiChoiceList
  options + selected set + onChanged

SettingsAction / PlatformPrimaryAction
  action variant -> iOS/Material/desktop presentation

SettingsAlert / showPlatformAlertDialog usage
  confirm/destructive/cancel semantics

SettingsFeedback / platform-safe lightweight feedback
  success/error/info without Scaffold-only dependency
```

命名可按现有代码风格微调，但页面调用方必须能表达“我要单选/多选/动作/确认/反馈”，而不是自己决定 `ChoiceChip`、`RadioListTile` 或 `CupertinoDialogAction`。

### Decision: Apple mobile 不靠“全局包 Material”解决

不要在 `PlatformListSection` 的 iOS 分支整体包 `Material` 来压住报错。那会掩盖混用问题，也会让 Apple settings 容器继续承载 Material 控件。更好的方向是：

- iPhone/iPadOS 使用 Cupertino-safe row、segmented/picker/checkmark list、Cupertino action。
- Material 平台继续使用 Material chip/radio/checkbox/button。
- 弹出式 picker/sheet 如果内部确实复用 Material widget，必须由 platform transient seam 明确提供 Material surface。

### Decision: `PlatformPrimaryAction` 名字必须兑现平台语义

当前 `PlatformPrimaryAction` 内部主要返回 `FilledButton` / `OutlinedButton` / `TextButton`。实现阶段应让它在 iPhone/iPadOS 分支返回 Cupertino-safe action（例如 `CupertinoButton` 或等价实现），并保持桌面按钮 bounded/aligned 行为不倒退。

### Decision: 控件 seam 不拥有业务状态

settings/platform 控件只处理 UI 表达和交互回调，不读取 provider、不写 repository、不导入 feature-specific model。选项 label、selected value、disabled、danger、action handler 都由页面传入。

```text
features/settings page
  -> SettingsOptionChoiceRow(label, value, options, labelFor, onChanged)
       -> platform/settings seam
            -> Cupertino-safe / Material-safe render
```

### Decision: 测试以 iOS Cupertino 分支为第一防线

新增或调整 widget tests 时应设置 `debugPlatformTargetOverride = TargetPlatform.iOS`，pump 核心控件在 `SettingsPage` + `SettingsSection` 内的真实结构，断言：

- `tester.takeException()` 为空。
- 单选/多选/chip replacement 能正确显示 selected 状态。
- 交互触发 `onChanged`。
- action/dialog/feedback 的 Apple mobile 分支不依赖 `Scaffold` 或 accidental `Material` ancestor。

## Risks / Trade-offs

- [Risk] 一次补齐多个 seam 容易扩大范围。→ Mitigation: 只提供通用控件，不迁移全部页面；具体替换放到第二个 change。
- [Risk] iPhone 上 chip 可能从 inline chip 变成 row/picker，交互路径变化。→ Mitigation: 控件语义允许 Apple mobile 使用更系统的行选择或 segmented 表达；测试覆盖 selected display 和回调。
- [Risk] `PlatformPrimaryAction` 变更影响现有页面。→ Mitigation: 保持 constructor API，先以视觉兼容和 Apple-safe 为目标，必要时增加 variant 行为测试。
- [Risk] settings 是 coupled hotspot。→ Mitigation: 把重复控件逻辑抽到 settings/platform seam，减少页面级 Material/Cupertino 分支扩散。

## Migration Plan

1. 梳理现有 `SettingsMenuRow`、`SettingsToggleRow`、`SettingsInputRow`、`SettingsAction`、`PlatformPrimaryAction`、`PlatformDialog` 的能力缺口。
2. 新增或扩展 settings semantic controls，覆盖 chip/single-choice/multi-choice/action/dialog/feedback/progress。
3. 让 Apple mobile 分支使用 Cupertino-safe 控件或自绘轻量控件，不依赖 `Material` ancestor。
4. 保持 Material/desktop 分支视觉和交互尽量接近现状。
5. 添加 iOS widget tests 覆盖核心 settings controls。
6. 运行 focused tests、`flutter analyze` 和按需要 `flutter test`。

Rollback: 如某个新 seam 交互不理想，可以保留 API 但切回更保守的 row + platform picker 表达；不得回退到页面内直接嵌入 Material-only 控件作为长期方案。

## Open Questions

- Apple mobile 上 chip group 应优先渲染为 inline Cupertino segmented-style control，还是统一渲染为 value row + picker。实现时可按空间和选项数量决定。
- feedback seam 是否优先复用现有 toast/top-toast，还是新增 settings-local inline feedback row。需要结合现有 `TopToast` 和 `ScaffoldMessenger` 使用范围评估。
