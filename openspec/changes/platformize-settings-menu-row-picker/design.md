## Context

日志中的 Flutter error 指向 `memos_flutter_app/lib/features/settings/settings_ui.dart:837` 附近的 `DropdownButton<ImageCompressionMode>`。当前结构是：

```text
SettingsMenuRow<T>
  └── PlatformListSectionRow
      └── iPhone/iPadOS: CupertinoListTile
          └── trailing: DropdownButton<T>
```

`CupertinoListTile` 不提供 Material surface，而 `DropdownButton<T>` 在 build 阶段会检查最近的 `Material` ancestor，因此 iOS 真机进入图片压缩设置时触发 `No Material widget found`。同一个通用组件还被 `LocationSettingsScreen`、`AiProxySettingsScreen` 等设置页复用，所以局部修图片压缩页不足以根治。

项目已有 `showPlatformPicker` / `showPlatformPopoverOrSheet`，且 `platformize-onboarding-language-selection` 已经用该 seam 解决 onboarding 语言 `DropdownButton` 在 Apple mobile 上的同类问题。设置页应沿用这个方向。

## Goals / Non-Goals

**Goals:**

- 让 iPhone/iPadOS 设置页中所有 `SettingsMenuRow<T>` 都能渲染并交互，不再触发 `No Material widget found`。
- 将设置页 enum/single-option selection 收敛到 `SettingsMenuRow<T>` 和 `showPlatformPicker`，减少页面局部 Material-only 控件假设。
- 保持现有设置页状态更新、label 映射、disabled 语义和 provider mutation path 不变。
- 增加 focused iOS widget tests 覆盖真实 Cupertino 分支。

**Non-Goals:**

- 不重新设计完整 settings 信息架构。
- 不迁移所有项目中的 `DropdownButton`，只处理设置语义组件 `SettingsMenuRow<T>` 的问题。
- 不改变 `showPlatformPicker` 的全局默认视觉策略，除非实现中发现该 seam 无法安全承载设置选择。
- 不修改 API、数据库、WebDAV、同步协议、本地库路径或商业/private seam。

## Decisions

### Decision: `SettingsMenuRow<T>` 改为 picker row，而不是给 dropdown 局部包 `Material`

实现阶段应让 `SettingsMenuRow<T>` 显示当前选项文本和进入选择的 chevron/affordance，点击后打开 `showPlatformPicker`。picker 内容可用 `ListTile` / radio icon 表达选项，因为 iOS popup 分支已由 `showPlatformPopoverOrSheet` 包裹透明 `Material`。

```text
SettingsMenuRow<T>
  ├── PlatformListSectionRow
  │   ├── title: SettingsRowTitle(label)
  │   ├── additionalInfo: selected label
  │   └── trailing: chevron
  └── onTap -> showPlatformPicker<T>
          └── option list -> onChanged(next)
```

Alternatives considered:

- `Material(type: MaterialType.transparency)` 包住 `DropdownButton`：改动最小，但仍让 Apple settings 使用 Material dropdown，且没有复用已有平台 picker seam。
- 在 `PlatformListSectionRow` 的 iOS 分支全局包 `Material`：可能掩盖更多混用问题，并改变所有 Apple grouped list 内容的 surface 假设。
- 每个设置页自建 picker：会重复 selection 逻辑，让 `settings` coupled area 更分散。

### Decision: 保持 `SettingsMenuRow<T>` 调用方语义稳定

调用方仍通过 `values`、`value`、`labelFor`、`onChanged` 描述选择意图。实现可以新增内部 helper，但不应要求所有调用方改成 page-local `_selectEnum`，否则会扩大改动面并复制现有 `PreferencesSettingsScreen` 的选择逻辑。

### Decision: iOS 测试必须覆盖 Cupertino 分支

现有设置测试多在默认 Material platform 下运行，无法覆盖 `CupertinoListSection` / `CupertinoListTile` 分支。实现阶段应设置 `debugPlatformTargetOverride = TargetPlatform.iOS`，用手机 viewport pump 相关设置页或通用 `SettingsMenuRow<T>`，断言：

- `tester.takeException()` 没有 `No Material widget found`。
- 点击 row 后 picker option surface 出现。
- 选择非当前项会调用 `onChanged` 并更新显示。

### Decision: 保持平台层依赖方向

如果实现需要调整 `platform/widgets/platform_picker.dart`，该文件仍不得导入 `features/*`、`state/*`、`application/*` 或 `data/*`。settings-specific label、row、状态更新都留在 `features/settings/settings_ui.dart` 或调用方现有 provider seam。

## Risks / Trade-offs

- [Risk] 从 inline dropdown 改为点击行 + picker 会改变设置项交互路径。→ Mitigation: 设置行显示当前值和 chevron，符合 settings value-row 语义，并通过 tests 覆盖选择行为。
- [Risk] picker 内选项如果直接使用 Material `ListTile`，iOS popup 仍可能缺少 Material。→ Mitigation: 复用 `showPlatformPicker`，其 iOS `showPlatformPopoverOrSheet` 分支已经包透明 `Material`。
- [Risk] `SettingsMenuRow<T>` 是通用组件，行为变更影响多个设置页。→ Mitigation: 保持构造参数和 `onChanged` 行为稳定，添加通用组件测试和至少一个真实页面测试。
- [Risk] 设置页 touched area 已是 coupled hotspot。→ Mitigation: 把选择逻辑收敛到通用 settings seam，避免页面级分支扩散。

## Migration Plan

1. 在 `SettingsMenuRow<T>` 中移除 `DropdownButtonHideUnderline` / `DropdownButton<T>`，改为显示当前 value label 的语义设置行。
2. 添加内部 `_showMenuPicker` 或等价 helper，调用 `showPlatformPicker<T>` 展示 `values`。
3. 在 picker option 中复用 `labelFor`，选中项显示 radio/check 状态，点击后关闭 picker 并调用 `onChanged(next)`。
4. 更新现有 widget tests 对 `DropdownButton` 的实现细节断言，改为断言 row、value 和交互结果。
5. 新增 iOS 平台测试覆盖 `ImageCompressionSettingsScreen` 或 `SettingsMenuRow<T>`。
6. 运行 focused tests，再运行 `flutter analyze` 和按需 `flutter test`。

Rollback: 如出现无法接受的交互回归，可临时回退为透明 `Material` 包裹旧 dropdown，但应保留 iOS smoke test 作为防线，并把 picker 化作为后续任务继续完成。

## Open Questions

- picker option 是否需要在 iPhone 上使用 `CupertinoActionSheet` 风格而不是当前 platform picker list。实现前可优先复用现有 `showPlatformPicker`，除非截图/测试显示交互明显不合适。
- `SettingsMenuRow<T>` 是否应支持可选 `description` 或 `desktopMaxWidth`。本次优先保持现有 API，避免扩大改动范围。
