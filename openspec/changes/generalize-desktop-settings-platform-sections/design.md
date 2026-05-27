## Context

`settings_screen.dart` 当前只在 `TargetPlatform.windows` 下显示 Windows 相关设置入口，`windows_related_settings_screen.dart` 又在页面内部使用 `Platform.isWindows` 做二次 gate，并自带 `Scaffold`、palette、私有 group/row/toggle 实现。独立桌面设置窗口的左侧 pane 也硬编码为 `Windows settings`，实际入口与页面命名都把桌面级能力绑定到了 Windows。

已有 `settings_ui.dart` 提供 `SettingsPage`、`SettingsSection`、`SettingsNavigationRow`、`SettingsToggleRow` 等语义 seams；`platform_target.dart` / `Theme.of(context).platform` 已能表达 Windows、macOS、Linux desktop target。现有 settings UI drift guardrail 也已经把迁移后的 settings page 与 legacy allowlist 区分开。

依赖方向现状：settings 页面直接组合 feature UI 和 state provider；`WindowsRelatedSettingsScreen` 同层引用 `DesktopShortcutsSettingsScreen` 和 `devicePreferencesProvider`，没有要求 lower layer 反向依赖 features。本变更后的方向保持在 `features/settings` 内做 UI 组合，继续读取现有 settings state owner，不向 `state`、`application`、`core` 添加新的 `features/*` 依赖。

## Goals / Non-Goals

**Goals:**
- 把用户可见入口和页面标题统一为“桌面设置”。
- 让主设置页和独立桌面设置窗口使用同一个 desktop settings 语义入口。
- 按平台分段展示共享桌面项和平台专属项：Windows/macOS 可见共享桌面快捷键，Windows 可见 close-to-tray，Linux 明确处于未适配或 fallback 状态。
- 用 `SettingsPage` / `SettingsSection` / row seams 替换页面本地视觉实现，并收紧 guardrail。
- 保持 `windowsCloseToTray` 的 Windows 专属语义和现有 persistence owner。

**Non-Goals:**
- 不迁移所有其他设置项 UI；后续由独立 change 覆盖。
- 不完成 Linux 桌面端适配，只提供清晰 fallback。
- 不新增桌面设置业务模型、repository 或跨层 state owner。
- 不改变 Windows close-to-tray 生命周期语义。
- 不引入任何商业、订阅、StoreKit、entitlement 或 private overlay 行为。

## Decisions

### 1. 用 `DesktopSettingsScreen` 语义替代 Windows 命名

实现时应将页面概念重命名为 `DesktopSettingsScreen` 或等价公开 widget。旧 `WindowsRelatedSettingsScreen` 可以删除；如果短期仍有路由、测试或外部引用需要稳定，可保留薄 wrapper，但 wrapper 只能委托到新页面，不能继续承载 Windows-only 逻辑。

Alternatives considered:
- 只把标题改成“桌面设置”：实现成本最低，但类名、文件名、入口 gate 和独立窗口 pane 仍然会继续表达 Windows 专属抽象。
- 创建 `WindowsSettingsScreen`、`MacosSettingsScreen`、`LinuxSettingsScreen` 三套页面：短期清晰，但违反 platform-adaptive UI 体系中“不复制完整平台页面树”的方向。

### 2. 平台差异用同层 section model 表达

桌面设置页应在 `features/settings` 同层构造 section/row 列表，例如私有 helper 或轻量 section descriptor，输入为当前 `TargetPlatform` / `PlatformTarget`、现有 prefs 和 callbacks，输出为 settings UI seam widgets。平台判断可以来自 `Theme.of(context).platform` 或既有 `resolvePlatformTarget(context)`，避免页面内混用 `dart:io Platform.isWindows` 与 Flutter target override。

Alternatives considered:
- 在每个 row 周围直接写多个 `if (Platform.isX)`：简单但容易让平台分支继续散落在页面布局中。
- 把 section 决策下沉到 `state` 或 `core`：会让 UI 平台语义进入低层，增加已知 reverse dependency 风险。

### 3. 共享桌面能力与平台专属能力分段

共享桌面分段承载 Windows/macOS 都支持的桌面能力，当前最明确的是桌面快捷键设置。Windows 分段保留 `windowsCloseToTray`。macOS 分段只显示已经真实支持且与桌面设置相关的配置；如果当前没有 macOS 专属配置，不展示空功能或虚构开关。Linux 分段显示“暂未适配/当前无可用桌面设置”的 fallback，直到后续 Linux change 明确支持范围。

Alternatives considered:
- 在 macOS 上隐藏整个桌面设置入口：会继续把共享桌面快捷键能力误认为 Windows-only。
- 对 Linux 直接显示完整桌面设置：当前用户明确说明 Linux 桌面端未适配，这会扩大承诺。

### 4. 入口一致性由 SettingsScreen 和 DesktopSettingsWindowApp 共同遵守

主设置页应从 `isWindowsDesktop` gate 改为 desktop target gate（Windows/macOS；Linux 根据 fallback 策略可显示或隐藏，但如果显示必须明确未适配）。独立桌面设置窗口应把 pane enum/label/route 从 Windows 语义改为 desktop settings 语义，并渲染同一个页面。

Alternatives considered:
- 只改主设置页：macOS 独立 settings window 仍会出现 Windows settings pane。
- 只改独立 settings window：普通 settings route 仍然是 Windows-only，用户入口不一致。

### 5. Guardrail 作为本次 evolve_modularity 改善

本变更触及 settings hotspot，模块化改善应落在两个地方：迁移桌面设置页到 settings UI seams，并把迁移后的页面加入 `migratedFiles`、移出 legacy allowlist；必要时增加覆盖平台分段的 widget tests。这样可以防止新桌面设置页重新引入 page-local Scaffold、palette、bare Switch 或私有 row/card UI。

Alternatives considered:
- 只靠人工 review：无法在后续设置页面继续迁移时防止漂移。

## Risks / Trade-offs

- [Risk] 重命名文件或类会遗漏引用，导致 settings window pane 或 pushed route 仍指向旧页面。→ Mitigation: 使用 `rg WindowsRelatedSettingsScreen|windows_related|msg_windows_related_settings` 做引用清理，并保留短期 wrapper 时添加测试覆盖。
- [Risk] i18n key 替换过宽，误改 Windows 系统权限类文案。→ Mitigation: 只替换桌面设置入口和桌面快捷键泛化文案；`msg_windows_enable_location_access`、`msg_windows_paging_note` 等真实 Windows 行为文案保留。
- [Risk] Linux fallback 与入口可见性不一致。→ Mitigation: 在 spec 和 tests 中明确 Linux 当前不是完整支持平台；如果显示入口，页面必须显示未适配 fallback。
- [Risk] `desktop_shortcuts_settings_screen.dart` 本身仍含 Windows 命名文案。→ Mitigation: 本 change 只泛化桌面设置入口和共享桌面快捷键描述；如果快捷键页面内部仍有 Windows-only 假设，任务中单独检查并最小修正文案或 gating。
- [Risk] 收紧 guardrail 可能暴露更多 legacy settings drift。→ Mitigation: 本 change 只要求迁移桌面设置页；其他 settings 文件继续由后续 change 处理。

## Migration Plan

1. 新建或重命名桌面设置页，并用 settings UI seams 重写页面结构。
2. 更新主设置页和独立桌面设置窗口的 pane label、icon、route 和 platform gate。
3. 更新 i18n key 与生成文件。
4. 补充平台分段 widget tests 和 settings UI drift guardrail。
5. 运行 focused tests、`flutter analyze`，并按需要执行 settings 相关 widget tests。

Rollback strategy: 如果平台分段行为出现回归，可以保留 `DesktopSettingsScreen` 名称和 i18n，同时临时把 macOS/Linux 入口隐藏；Windows close-to-tray 和快捷键入口仍可通过同一页面继续工作。

## Open Questions

- macOS 当前是否已有除桌面快捷键以外的桌面设置项需要归入 macOS 分段？若没有，实施时不应创建空的 macOS 专属开关。
- Linux 入口最终选择隐藏还是显示 fallback，需要实现时结合现有产品入口习惯决定；无论选择哪种，都不能把 Linux 标记为完整适配。
