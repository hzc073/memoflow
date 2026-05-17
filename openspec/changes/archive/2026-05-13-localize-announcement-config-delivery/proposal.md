## Why

更新公告和通知公告正在走向同一套可运营 delivery model：状态、渠道、平台、发布时间、过期时间、展示位置、关闭策略等字段应当由配置控制，而不是散落在 legacy 更新弹窗逻辑里。

当前更新公告内容仍然把 `zh` 和 `en` 放在同一个 `announcements/{id}.json` 中。随着应用已经支持 `zh-Hans`, `zh-Hant-TW`, `en`, `ja`, `de`, `pt-BR`, and `ko`，继续把多语言内容塞进一个配置文件会让公告编辑、AI 翻译、人工校对和发布审核变得脆弱。我们需要把“给谁看、何时看、在哪看”的运营控制和“用某种语言怎么说”的文案内容拆开。

## What Changes

- Introduce locale-scoped announcement content files in the `memoflow_config` source layout.
- Keep delivery control fields language-neutral and centralized in the manifest / delivery candidate layer.
- Generate locale-specific client outputs so each modern client fetches and accepts only the config for its resolved app locale.
- Use English as the default fallback when a locale-specific announcement body is missing.
- Preserve v2 compatibility by continuing to generate a v2-compatible default output for old clients.
- Do not preserve v1 compatibility; v1-only source/output shapes are out of scope for this change.
- Add local config manager AI-assisted translation support so a Chinese source announcement can generate draft localized variants for review.
- Mark AI-generated translations as drafts/stale until reviewed; AI output must not publish directly.

## Non-Goals

- No push notification service.
- No backend admin console outside the localhost-only config manager.
- No runtime AI translation in the Flutter app.
- No subscription, entitlement, paywall, or private overlay behavior.
- No compatibility guarantee for v1 config clients or v1-only config source files.
- No automatic publishing of AI-generated translations without human review.

## Capabilities

### New Capabilities

- `announcement-config-localization`: Defines locale-scoped announcement config delivery, English fallback, v2 compatibility output, v1 non-compatibility, and AI-assisted translation authoring.

### Related Capabilities

- `update-announcement-channel-routing`: Future implementation must preserve channel/platform update prompt behavior while moving update announcement content to localized outputs.
- `app-localization`: Future implementation should use the same effective app locale resolution as the app UI when choosing localized config URLs.

## Impact

- Affected planning/implementation areas:
  - `F:\Homework\memoflow_config\update\manifest.json`
  - `F:\Homework\memoflow_config\update\announcements\...`
  - `F:\Homework\memoflow_config\config\server.py`
  - `F:\Homework\memoflow_config\config\manager.*`
  - `F:\Homework\memoflow_config\.github\scripts\build_update_config.py`
  - `memos_flutter_app/lib/data/updates/update_config_service.dart`
  - `memos_flutter_app/lib/data/updates/update_config.dart`
  - `memos_flutter_app/lib/application/updates/...`
  - Debug preview and announcement validation tooling
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched:
  - Item 2, no `application -> features` reverse dependencies: locale-aware config selection should remain in data/application seams, not feature dialogs.
  - Item 4, no reused shared domain logic hidden inside screen or widget files: locale fallback, v2 compatibility, and candidate resolution must live in reusable parsing/building/policy helpers rather than UI methods.
  - Item 7, touched write paths have clear owners: config repository writes should stay owned by the local config manager repository/service layer.

