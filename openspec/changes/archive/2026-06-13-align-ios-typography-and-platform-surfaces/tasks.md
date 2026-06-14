## 1. Policy 与测试准备

- [x] 1.1 在 `memos_flutter_app/test/core` 或等效位置新增 focused typography policy tests，覆盖 iPhone/iPadOS 忽略 persisted `fontFamily` / `fontFile` 的 effective app chrome 字体行为。
- [x] 1.2 增加 non-iOS regression tests，确认 Android、Windows、macOS、Linux 已支持的字体选择/effective font 行为不被移除。
- [x] 1.3 增加 iOS text scaling tests，确认系统 `MediaQuery.textScaler` 会参与 effective scaler，且 `AppFontSize.standard` 不会退化为固定 `TextScaler.linear(1.0)`。
- [x] 1.4 增加 iOS UI line-height scope tests，确认 Apple mobile UI chrome 不强制使用 reader-oriented `AppLineHeight`。

## 2. Typography policy 实现

- [x] 2.1 新增或集中 `EffectiveAppTypography` policy/helper，输入 platform classification、`AppFontSize`、`AppLineHeight`、`fontFamily`、`fontFile` 和 existing text scaler，输出 effective font、fallback、text scaler 与 line-height scope。
- [x] 2.2 调整 `memos_flutter_app/lib/core/app_theme.dart`，通过 policy 解析 effective `fontFamily` / fallback，并在 iOS/iPadOS app chrome theme 中使用系统字体。
- [x] 2.3 调整 `memos_flutter_app/lib/app.dart` 的 `MediaQuery.textScaler` 组合逻辑，使 iOS/iPadOS 保留系统 text scaling 并叠加 app font-size preference。
- [x] 2.4 如需要，调整 `memos_flutter_app/lib/platform/shells/apple_shells.dart` 的 `CupertinoThemeData` typography 映射，但必须只消费 policy 输出，不重新解析 preferences。

## 3. Settings 字体入口

- [x] 3.1 为 settings 字体入口提供 platform capability 或 policy helper，例如 `canChooseSystemFonts` / `effectiveFontLabel`，避免 settings 只通过空字体列表推断能力。
- [x] 3.2 调整 `memos_flutter_app/lib/features/settings/preferences_settings_screen.dart`，让 iPhone/iPadOS 字体入口隐藏、禁用或只读显示系统默认，并且不会打开空系统字体 picker。
- [x] 3.3 保留 desktop/Android 现有字体 picker 行为，包括已选择字体 label、system default label、字体加载和 provider mutation path。
- [x] 3.4 补充 `memos_flutter_app/test/features/settings/platform_adaptive_settings_test.dart` 或等效 iPhone/iPadOS widget tests，验证字体入口不会呈现无效 picker。

## 4. Modularity 与边界保护

- [x] 4.1 确认新增/修改的 typography policy 位于稳定层，不依赖 `features/*`、`application/*` 或 page implementation details。
- [x] 4.2 若修改 `memos_flutter_app/lib/platform`，新增或扩展 architecture guardrail，阻止新的 `platform -> features/state/application/data` dependency。
- [x] 4.3 确认 `app.dart` 仍主要作为 composition root，具体 platform typography decision 委托给 policy/seam。
- [x] 4.4 检查 touched public Apple/settings files，确认没有新增 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching。

## 5. 验证

- [x] 5.1 在 `memos_flutter_app` 运行新增 focused typography policy tests。
- [x] 5.2 在 `memos_flutter_app` 运行 focused settings/platform widget tests。
- [x] 5.3 在 `memos_flutter_app` 运行相关 architecture guardrail tests。
- [x] 5.4 在 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 5.5 在 `memos_flutter_app` 运行 `flutter test`。
- [x] 5.6 提交前检查 staged 和 unstaged changes，确认没有商业、订阅、计费、entitlement、paywall、StoreKit 或其他 paid-feature code 泄漏到 public repository。

## 6. iOS 设置行 value metadata 修复

- [x] 6.1 在 delta spec/design 中补充 settings value metadata 必须映射到平台原生 row slot，并在 iOS 大字号下保持 bounded 的规则。
- [x] 6.2 调整 `PlatformListSectionRow` 或等效 settings/platform seam，暴露 `additionalInfo`/metadata slot；iPhone/iPadOS 映射到 Cupertino additional-info，Material 平台保持现有 trailing presentation。
- [x] 6.3 调整 `SettingsValueRow` / `SettingsNavigationRow`，把 value label 交给 metadata slot，chevron/switch/icon 保持 trailing control。
- [x] 6.4 补充 iPhone Preferences 大字号 widget test，覆盖 value label 不再作为 unconstrained trailing control 且不会触发布局 overflow。
- [x] 6.5 补充或确认 Android/Material row 行为不因 iOS metadata slot 修复而改变。
