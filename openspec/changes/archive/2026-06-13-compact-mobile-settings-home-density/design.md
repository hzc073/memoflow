## Context

当前设置首页结构是：

```text
SettingsScreen
  -> SettingsHomeProfileEntry
  -> SettingsHomeShortcutTile
  -> SettingsHomeSection
       -> SettingsNavigationRow
            -> PlatformListSectionRow
```

在 Android phone 上，`PlatformListSectionRow` 最终渲染 Material `ListTile`。单行 `ListTile` 默认最小高度为 56 logical pixels，因此截图中的普通设置行即使没有显式 `SizedBox`，也会显得偏高。与此同时，`SettingsHomeHierarchyTokens` 目前在 phone 上使用 `shortcutTileHeight: 92`、`sectionSpacing: 16`、`profilePadding: 18`，叠加后让首屏可见内容进一步减少。

上一轮 `enhance-mobile-settings-home-hierarchy` 的设计目标是增强手机端设置首页层级：profile card、独立 shortcut tiles、grouped sections、row dividers。这个目标仍然成立。本 change 只调整密度，不撤销层级模型。

## Goals / Non-Goals

**Goals:**

- 将手机端设置首页普通单行功能入口压到 48 logical pixels 左右。
- 将第一版 home hierarchy 数值收敛为 `shortcutTileHeight: 80`、`sectionSpacing: 12`、`profilePadding: 16`。
- 保持普通功能入口 grouped section + divider，不把每行拆成独立卡片。
- 将 density 作为 settings-owned home hierarchy token 或 semantic row density seam 表达，而不是在 `settings_screen.dart` 写局部尺寸。
- 保持二级/三级设置页和 desktop settings 的现有密度。
- 用 focused tests / guardrail 保护范围。

**Non-Goals:**

- 不修改设置首页入口顺序、导航目标、haptic 行为、extension entry 排序、DonationDialog 行为、account/local library 逻辑。
- 不修改所有 settings 页面或全 app list row 的默认高度。
- 不修改 API route adapters、request/response models、数据模型、数据库、同步协议、AI provider、private hooks 或商业逻辑。
- 不改变 app-wide button theme、商业/private seam 或 `AccessDecision.source` 语义。
- 不在本 change 中重新调整色彩、阴影强度、圆角体系；如截图验证发现矮卡片与圆角明显不协调，后续实现 MAY 小幅调整 home-only radius token，但需保持在 settings seam 并补测试。

## Decisions

1. **密度调整使用 home-only token/seam。**

   - 方案：在 `SettingsHomeHierarchyTokens` 增加或扩展普通功能行密度 token，例如 `navigationRowMinHeight` / `navigationRowContentPadding` / 等价语义字段，并将 phone 数值设为 48。
   - 理由：截图问题只发生在设置首页手机端。直接改 `SettingsNavigationRow` 或 `PlatformListSectionRow` 默认值会影响大量二级/三级设置页。
   - Alternative considered: 在 `settings_screen.dart` 外层包 `SizedBox(height: 48)`。该方案短期直接，但违反 settings UI seam/guardrail，后续难维护。

2. **调整现有 home hierarchy 数值，不新增页面结构。**

   - 方案：phone `shortcutTileHeight` 从 92 调到 80，`sectionSpacing` 从 16 调到 12，`profilePadding` 从 18 调到 16。
   - 理由：这些值已经集中在 `settingsPageTokens`，最小改动即可降低首页整体滚动高度。
   - Alternative considered: 重排首页入口或合并 section。该方案会改变信息架构，超出本反馈范围。

3. **普通功能入口仍保留 grouped section。**

   - 方案：`SettingsHomeSection` 继续包裹 `SettingsNavigationRow`，section 内保留 divider。
   - 理由：上一轮需求明确普通功能入口不应被拆成独立卡片。降低 row height 和 section spacing 足以解决当前密度问题。

4. **Apple mobile 与 Material mobile 保持平台语义。**

   - 方案：Material phone 单行普通功能入口 SHALL use 48 logical pixels as compact target. iPhone/iPad 可通过 Cupertino row 参数或 native compact baseline 表达同等密度，但不得为了统一数值反向放大原生较紧凑单行行高。
   - 理由：截图更像 Android Material phone。iOS 的 Cupertino single-line baseline 本身更紧凑，强行拉到 48 可能反而增加高度。

5. **测试覆盖范围而不是截图像素。**

   - 方案：widget tests 验证 home tokens 数值、Material phone row height、shortcut tile height、section spacing/profile padding 来源，以及二级/三级页面不继承 home compact treatment。
   - 理由：该问题来自密度 token 与 row seam，focused tests 比脆弱截图更适合阻止范围回归。

## Dependency Direction

- Before: `settings_screen.dart` 组装设置首页结构；`settings_ui.dart` 拥有 home hierarchy tokens；`platform_list_section.dart` 承载跨平台 row/section 渲染。
- After: 依赖方向保持不变。`settings_screen.dart` 不获得新的 platform 或视觉硬编码责任；`settings_ui.dart` 继续拥有 settings home density；如修改 `platform_list_section.dart`，它只接收通用 semantic row density 参数，不导入 `features/*`。

本 change 触及 settings UI coupled area。在 `evolve_modularity` 阶段，改动通过集中 home density token/seam 和 focused tests/guardrail 让 touched area equal or better structured。

## Risks / Trade-offs

- [Risk] 48dp 行高过紧，导致长文本或无障碍字体溢出。Mitigation: 仅作为单行最小高度，描述、多行或 text scale 情况允许自然增高，并测试不截断关键文本。
- [Risk] 快捷卡从 92 降到 80 后图标和文字显得拥挤。Mitigation: 保持 icon/label 居中布局，必要时只在 home token/seam 中微调图标间距。
- [Risk] 误把 compact treatment 扩散到二级设置页。Mitigation: 增加回归测试确认标准 `SettingsSection` 仍保持现有 mobile/desktop 密度。
- [Risk] Guardrail 误伤合法 platform seam 改动。Mitigation: 若必须扩展 `PlatformListSectionRow` 参数，测试只允许通用 semantic density API，不允许 `platform/` import `features/*`。
