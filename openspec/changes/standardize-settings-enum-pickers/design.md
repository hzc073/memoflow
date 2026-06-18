## Context

`PreferencesSettingsScreen` 当前同时存在两套单选弹窗实现：

- 旧 `_selectEnum<T>`：直接通过 `showPlatformPicker` 展示 `ListView + SettingsSection(header: Text(title)) + SettingsSingleChoiceRow`。
- 新 settings single-choice seam：通过 `showSettingsSingleChoicePicker` 统一处理标题、背景、最大高度、section、滚动和选项行。

用户截图中的“粉色外壳 + 白色 section + 标题贴边”来自旧 `_selectEnum<T>`。该旧入口目前覆盖语言、字体大小、行高、启动动作、主题模式，导致同一个 Preferences 页面内出现两套选择器视觉。实现层面这些设置只修改 `DevicePreferences`，无需改动 API、数据库、同步或模型结构。

本 change 位于 `evolve_modularity` 阶段，触碰 settings UI 耦合区域。改动目标是收敛页面私有 transient UI，复用现有 settings seam，避免继续复制页面级 picker 结构。

## Goals / Non-Goals

**Goals:**

- 统一 `PreferencesSettingsScreen` 中所有枚举型单选设置的 picker 视觉和交互。
- 保持每个枚举设置现有选项、过滤规则、当前值 label、多语言 label 和写入 callback 不变。
- 删除或收敛 `_selectEnum<T>` 旧实现，减少页面私有 picker 结构。
- 增加 focused widget tests，覆盖旧枚举入口打开后的新 picker 结构和选择写入行为。
- 保持 `settings_ui.dart` 作为 settings-owned semantic seam；调用方只传入 label、value、options、callback。

**Non-Goals:**

- 不重新设计 `showSettingsSingleChoicePicker` 的整体视觉语言。
- 不迁移其它页面中已经使用 `showSettingsSingleChoicePicker` 的选择器。
- 不修改 `DevicePreferences`、`AppPreferences`、存储格式或迁移逻辑。
- 不调整启动动作、语言、字体、主题本身的业务语义。
- 不触碰 `memos_flutter_app/lib/data/api/**` 或 `memos_flutter_app/test/data/api/**`。

## Decisions

### Decision 1: 复用 `showSettingsSingleChoicePicker`，不新增第三套 picker

所有旧 `_selectEnum<T>` 使用点应迁移到 `showSettingsSingleChoicePicker<T>` 或一个很薄的 Preferences 私有 helper，该 helper 也必须委托到 `showSettingsSingleChoicePicker<T>`。

选择该方案是因为 `showSettingsSingleChoicePicker` 已经承载 settings 选择器的标题、背景、section、滚动和 option row 行为，且已被标签识别、导航模式、WebDAV 等设置流使用。相比给 `_selectEnum<T>` 单独打补丁，复用 seam 能避免两个样式源继续分叉。

备选方案：只调整 `_selectEnum<T>` 内部 padding/background。该方案能修截图中的局部问题，但仍保留第二套 transient UI 结构，后续容易再次漂移，因此不采用。

### Decision 2: 枚举选项仍由调用点声明

语言、字体大小、行高、启动动作、主题模式各自保留现有 `values`、`label` 和 `selected` 来源；迁移只改变弹窗 presentation seam，不改变选项集合和写入路径。

启动动作仍必须保留现有过滤：`LaunchAction.sync` 不出现在用户可选列表中。主题模式仍使用当前 `themeMode` 和 `deviceNotifier.setThemeMode`。

### Decision 3: 将模块化改善限定为 UI seam 收敛

本 change 不适合引入新的跨层架构。模块化改善点是移除/收敛 `PreferencesSettingsScreen` 内页面私有 `_selectEnum<T>` picker 结构，让 Preferences 页面通过 settings-owned seam 表达单选 intent。

依赖方向保持：

- `features/settings/preferences_settings_screen.dart` 继续依赖 `features/settings/settings_ui.dart`。
- `settings_ui.dart` 不读取 Preferences 的 providers，也不引入 feature business state。
- `platform/widgets/*` 不新增对 `features/*`、`state/*`、`application/*` 或 `data/*` 的依赖。

### Decision 4: 测试以行为和结构为主，不依赖像素截图

测试应覆盖：

- 打开一个代表性旧枚举入口（例如行高）后，能看到统一 picker 标题和选项。
- 选择其它选项后，测试仓库或 controller 中的 `DevicePreferences` 被更新。
- 可选地覆盖启动动作过滤仍然排除 `LaunchAction.sync`。

不使用截图断言作为主要验收，因为现有 Flutter widget tests 对跨平台视觉像素较脆弱；结构和行为断言更稳定。

## Risks / Trade-offs

- [Risk] 迁移 helper 后某个枚举调用点遗漏特殊过滤规则。  
  Mitigation: 在任务中逐个列出 5 个旧入口，并为启动动作过滤补 focused test 或显式断言。

- [Risk] `showSettingsSingleChoicePicker` 返回 selected value，而旧 `_selectEnum` 直接在 row tap 中调用 callback，迁移可能改变取消/选择时序。  
  Mitigation: helper 中只在 selected 非空且 context 仍有效时调用 `onSelect`，保持取消不写入。

- [Risk] 文案或 label 多语言路径被误改。  
  Mitigation: 不改 i18n 文案；所有 label 继续调用现有 `labelFor(devicePrefs.language)`。

- [Risk] 旧 `_selectEnum` 删除影响未来快速新增 enum picker 的便利性。  
  Mitigation: 如需要保留 helper，命名应体现其委托到 settings seam，例如 `_selectSingleChoice<T>`，避免重建旧结构。
