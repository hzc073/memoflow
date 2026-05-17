## Context

MemoFlow 的本地化主路径使用 `slang`，资源位于 `memos_flutter_app/lib/i18n/*.i18n.yaml`，生成文件为 `memos_flutter_app/lib/i18n/strings.g.dart`。运行时偏好层使用手写 `AppLanguage`，再通过 `appLocaleForLanguage()` 映射到生成的 `AppLocale`。

当前支持 `en`, `zh-Hans`, `zh-Hant-TW`, `ja`, `de`, `pt-BR`。韩语设备 locale 目前会走默认英文路径；同时，少量非 Slang 文案和格式化路径散落在 `core`, `features`, `application/widgets`, `features/settings/desktop_settings_window_app.dart` 等位置。完整韩语版本需要覆盖这些路径，而不是只新增 `strings_ko.i18n.yaml`。

Architecture phase 是 `evolve_modularity`。本 change 触及跨层本地化行为和 `application/widgets` 里已有语言格式化逻辑；设计必须避免新增 `state -> features`, `application -> features`, 或 `core -> higher-layer` 依赖，并在 touched area 做一个 scoped modularity improvement。

## Goals / Non-Goals

**Goals:**

- 支持 `ko` 作为生成 locale、用户偏好枚举值、系统 locale 映射值和 UI 可选语言。
- 提供与英文 base resource 等价 key coverage 的 Korean Slang resource。
- 在 onboarding、settings、desktop settings window 中显示 Korean / 한국어。
- 补齐完整版本路径：image editor labels、sync feedback、home widget locale tags、AI/default prompt language guidance、代表性 binary helper 输出。
- 中央化重复的 language metadata，至少覆盖 locale tag 和 week-start behavior，避免为 `ko` 继续复制 per-feature switch。
- 添加 focused tests，验证 Korean locale generation、mapping、labels、placeholder rendering 和代表性非 Slang 文案路径。

**Non-Goals:**

- 不修改 Memos server API、request/response models、route adapters 或 API compatibility tests。
- 不引入新的 localization package；继续使用现有 `slang` / `slang_flutter`。
- 不增加 subscription、billing、entitlement、paywall 或 private overlay 逻辑。
- 不重构整个 i18n 架构，不一次性迁移所有历史 `trByLanguage(zh, en)` call sites。
- 不改变现有 language persistence 语义；新增值以 `AppLanguage.ko.name == "ko"` 保存。

## Decisions

### Decision 1: Korean uses a first-class `ko` Slang locale

Add `memos_flutter_app/lib/i18n/strings_ko.i18n.yaml` and regenerate `strings.g.dart` with `dart run slang`.

Rationale:
- `slang` already drives supported locales, generated accessors, Flutter `supportedLocales`, and runtime translations.
- A first-class locale lets `AppLocaleUtils.supportedLocalesRaw` include `ko` and keeps Flutter Material/Cupertino localization delegates aligned with app locale selection.

Alternatives considered:
- **Partial Korean labels only**: faster, but leaves most app screens English and contradicts the selected complete version.
- **Runtime overlay map**: avoids generation, but creates a second localization system and weakens type/key coverage.

### Decision 2: Add `AppLanguage.ko` and centralize language metadata

Add `AppLanguage.ko('legacy.app_language.ko')`, map Korean device locales in `appLanguageFromLocale()` / `appLocaleForLanguage()`, and introduce or extend stable core helpers for metadata such as:

- locale tag: `ko`
- week starts on Monday: `false` unless product decides otherwise
- English fallback preference: `false` for paths that should request Korean output
- Traditional Chinese preference: unchanged

Rationale:
- `AppLanguage` is the persisted preference and settings enum; Slang alone cannot expose Korean in current selection UI.
- `home_widget_snapshot_builder.dart` and `home_widgets_updater.dart` currently duplicate locale tag switches. Centralizing this avoids making the touched hotspot worse.

Dependency direction before:

```text
application/widgets ── owns duplicate AppLanguage switch
features/settings   ── owns duplicate AppLanguage -> AppLocale switch
core                ── owns main AppLanguage -> AppLocale switch
```

Dependency direction after:

```text
application/widgets ──▶ core localization metadata helper
features/settings   ──▶ core localization mapping helper where feasible
core                ── no dependency on state/application/features
```

This preserves existing downward/stable dependency direction and avoids adding new reverse dependencies.

Alternatives considered:
- **Add `ko` to each switch in place**: smallest diff, but duplicates language semantics and misses the required modularity improvement in `evolve_modularity`.
- **Move `AppLanguage` out of `data/models/app_preferences.dart`**: architecturally cleaner long-term, but too broad for a locale addition.

### Decision 3: Treat non-Slang user-visible islands as Korean coverage targets

Add Korean translations to manual maps and switch helpers that are user-visible:

- `ImageEditorI18n.apply()` receives a Korean map for image editor package labels.
- `sync_feedback.dart` returns Korean for sync success/failure/progress.
- desktop/home widget locale tag helpers produce `ko`.
- representative AI/import language guidance should request Korean instead of English when `AppLanguage.ko` is active.

Rationale:
- Users perceive these as part of the app language even though they are not all generated from Slang.
- Complete Korean support should not show unrelated English or Chinese phrasing in common flows.

Alternatives considered:
- **Only Slang resources**: compiles and covers most UI, but creates obvious mixed-language experiences.
- **Rewrite every `trByLanguage()` call immediately**: stronger long-term direction, but high risk because some calls are AI prompt semantics rather than direct UI labels.

### Decision 4: Expand tests around representative behavior, not every string

Add focused tests that verify:

- `AppLocaleUtils.supportedLocalesRaw` contains `ko`.
- `appLanguageFromLocale(Locale('ko'))` returns `AppLanguage.ko`.
- `appLocaleForLanguage(AppLanguage.ko)` returns `AppLocale.ko`.
- Korean labels render in `languages`, `languagesNative`, and `legacy.app_language`.
- representative parameterized Korean strings preserve runtime placeholders.
- representative manual-path Korean strings are returned for sync/image-editor or equivalent helper targets.

Rationale:
- Full string-by-string translation quality is a content review problem; automated tests should guard integration and high-risk placeholder/key behavior.

Alternatives considered:
- **Snapshot every Korean string**: noisy and brittle.
- **No tests because Slang checks keys**: misses app-specific mapping, persistence, and manual islands.

## Risks / Trade-offs

- Korean translation quality may vary across ~1,978 strings → Mitigate with Korean copy review and placeholder-focused automated checks.
- Generated file churn in `strings.g.dart` will be large → Mitigate by keeping runtime logic changes small and separating generated/resource changes in review when possible.
- Persisted `"ko"` preferences can break older builds if users downgrade → Mitigate by documenting rollback caveat; current enum persistence already has this trade-off for newly added languages.
- `trByLanguage()` is binary by design → Mitigate by adding narrowly scoped Korean-aware helpers or migrating representative AI/import paths without broad architecture churn.
- PowerShell may corrupt non-ASCII output if used unsafely → Mitigate by using UTF-8-safe editing paths and verifying key Korean strings after write/generation.

## Migration Plan

1. Add Korean resource and enum/mapping support.
2. Regenerate `strings.g.dart` with `dart run slang`.
3. Update manual localization islands and centralized metadata helpers.
4. Add/adjust focused localization tests.
5. Run targeted localization tests, then `flutter analyze` and `flutter test` from `memos_flutter_app`.

Rollback:
- Revert the change as a unit. If a user has already saved `language: "ko"`, older builds may fall back according to existing preference parsing behavior or require resetting language preference.

## Open Questions

- Should Korean week labels in desktop/home widgets follow Sunday-first or Monday-first? The initial plan keeps Sunday-first for consistency with current non-German behavior.
- Should AI analysis prompts be fully Korean-authored now, or should the first implementation only ensure they explicitly request Korean output while preserving existing prompt structure?
