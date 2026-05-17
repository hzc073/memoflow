## Why

The app currently supports English, Chinese, Japanese, and German, but Brazilian Portuguese users cannot select a localized UI. Adding Portuguese (Brazil) improves accessibility for `pt-BR` users and aligns the language picker with a broader international audience.

## What Changes

- Add Brazilian Portuguese as a supported app locale using `pt-BR`.
- Add complete `pt-BR` translation resources generated from the English source strings using AI-assisted translation, with placeholders, interpolation variables, and technical identifiers preserved.
- Surface Portuguese (Brazil) in onboarding and settings language selection.
- Map device/system Portuguese locales to the new app locale, preferring `pt-BR` for `pt` and `pt-BR` system languages.
- Regenerate Slang localization accessors from YAML resources.
- Add focused localization verification so the new locale is selectable, mapped correctly, and contains key Portuguese UI labels.

## Capabilities

### New Capabilities

- `app-localization`: App-wide supported locale behavior, language selection, generated localization resources, and locale mapping for Brazilian Portuguese.

### Modified Capabilities

- None.

## Impact

- Affected runtime files include `memos_flutter_app/lib/data/models/app_preferences.dart`, `memos_flutter_app/lib/core/app_localization.dart`, onboarding/settings language UI, `memos_flutter_app/lib/features/image_editor/i18n.dart`, and generated `memos_flutter_app/lib/i18n/strings.g.dart`.
- Affected localization resources include all existing `memos_flutter_app/lib/i18n/strings*.i18n.yaml` files for language labels plus a new `strings_pt-BR.i18n.yaml`.
- No server API, storage schema, sync protocol, subscription/private-hook, or commercial behavior changes are expected.
- Architecture phase is `evolve_modularity`. This change should not touch the known reverse-dependency hotspots (`state -> features`, `application -> features`, or `core -> higher layers`) and must preserve checklist items `1`, `2`, and `3`. It should improve checklist item `8` by adding or tightening localization guardrails and satisfy item `10` by leaving touched localization seams no worse structured than before.
