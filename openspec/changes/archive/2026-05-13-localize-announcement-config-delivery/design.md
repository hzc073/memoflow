## Context

现有公告系统已经分成几条链路：

```text
Flutter app
  UpdateConfigService
    -> latest.json / preview / custom / local JSON
    -> UpdateAnnouncementConfig
    -> AnnouncementDeliveryPolicy
    -> AnnouncementPresenter boundary

memoflow_config
  update/manifest.json
  update/announcements/{id}.json
  update/donors.json
  config/ localhost manager
  .github/scripts/build_update_config.py
```

`notices[]` and `updates[]` already carry many delivery controls. The weak spot is release/update announcement content: `announcements/{id}.json` stores localized maps such as `contents.zh` and `contents.en` in one source file, while the app now supports more locales.

## Goals / Non-Goals

**Goals:**

- Split update announcement content by locale.
- Keep delivery targeting centralized and language-neutral.
- Let modern clients fetch locale-specific config output and reject mismatched locale payloads.
- Default missing localized content to English.
- Keep v2 clients working through a generated v2-compatible output.
- Explicitly drop v1 compatibility from the new localized pipeline.
- Add AI-assisted translation in the local config manager as a draft-generation workflow.

**Non-Goals:**

- No app runtime call to AI providers for announcement translation.
- No per-user server-side targeting.
- No removal of v2-compatible output until old-client support is intentionally retired.
- No reliance on AI translation without human review.

## Proposed Shape

The important split is control versus content:

```text
                    language-neutral
                update/manifest.json
              +----------------------+
              | notices[]            |
              | updates[]            |
              | release_notes index  |
              | content_ref/id       |
              | status/schedule/etc. |
              +----------+-----------+
                         |
          +--------------+---------------+
          |              |               |
          v              v               v
   zh-Hans content   en content      ja/de/pt/ko...
   one locale only   one locale only one locale only
```

Example source shape:

```text
update/
  manifest.json
  announcements/
    index.json                    # ids, version/release metadata if needed
  locales/
    zh-Hans/announcements/20260511.json
    zh-Hant-TW/announcements/20260511.json
    en/announcements/20260511.json
    ja/announcements/20260511.json
    de/announcements/20260511.json
    pt-BR/announcements/20260511.json
    ko/announcements/20260511.json
```

Each locale content file should contain only one language:

```json
{
  "id": "20260511",
  "locale": "en",
  "title": "v1.0.32",
  "summary": [
    "..."
  ],
  "items": [
    {
      "category": "feature",
      "contents": [
        "..."
      ]
    }
  ],
  "translation": {
    "source_locale": "zh-Hans",
    "source_hash": "...",
    "status": "reviewed"
  }
}
```

## Client Output Strategy

Generate modern locale outputs:

```text
dist/update/latest.zh-Hans.json
dist/update/latest.zh-Hant-TW.json
dist/update/latest.en.json
dist/update/latest.ja.json
dist/update/latest.de.json
dist/update/latest.pt-BR.json
dist/update/latest.ko.json
```

Each output should include a top-level locale marker:

```json
{
  "schema_version": 3,
  "locale": "en",
  "fallback_locale": "en",
  "version_info": {},
  "updates": [],
  "notices": [],
  "announcement": {},
  "release_notes": []
}
```

Modern client behavior:

```text
effective app locale
  -> locale config URL list
  -> fetch latest.<locale>.json
  -> require config.locale == expected locale
  -> parse delivery controls and one-language content
  -> if content missing, fetch/use English fallback
```

Fallback policy:

```text
requested locale content exists and valid
  -> use requested locale

requested locale content missing
  -> use English content

English content missing
  -> do not show that announcement candidate
```

This keeps fallback deterministic and avoids silently showing arbitrary languages.

## Compatibility

### v2 compatibility

The build pipeline should continue generating a v2-compatible default output, probably `dist/update/latest.json`, for old clients. That output may keep the current mixed localized maps because v2 clients already understand them:

```json
{
  "schema_version": 2,
  "version_info": {},
  "announcement": {
    "contents": {
      "zh": [],
      "en": []
    }
  },
  "release_notes": []
}
```

The v2 compatibility output can be English + Chinese only if older clients only consume those keys. Modern clients should prefer locale-specific outputs.

### v1 non-compatibility

The localized pipeline should not generate or validate v1-only outputs. If a legacy v1 file still exists as historical fallback, it should not constrain this change. Validation can explicitly report v1 source shape as unsupported for localized delivery.

## AI Translation Workflow

AI support belongs in `memoflow_config/config`, not app runtime:

```text
zh-Hans source announcement
       |
       v
local config manager AI action
       |
       v
draft localized files
       |
       v
human review / edit / approve
       |
       v
validate + build
```

AI provider config should be local-only and excluded from generated public config. Good places to consider:

- local environment variables
- ignored local config file under `config/`
- localhost-only form state, never committed with secrets

Translation metadata should help detect drift:

```text
source_hash changed
  -> mark derived locale files stale
  -> block or warn before publish until reviewed
```

## Dependency Direction

Future implementation should preserve current announcement presentation direction:

```text
data/updates
  -> parses config and locale payloads

application/updates
  -> selects eligible delivery candidates

features/updates
  -> renders dialogs through existing presenter boundary
```

Do not put locale fallback, config URL selection, or candidate resolution into feature dialog widgets. Those rules are shared domain/application behavior.

## Risks / Trade-offs

- More generated files to publish -> Mitigation: generate index/summary and validate all locales in one build.
- Missing translations can hide announcements for non-English locales -> Mitigation: English fallback is mandatory; English missing blocks display.
- AI translation can be subtly wrong -> Mitigation: draft/stale/reviewed metadata and human approval before public status.
- v2 compatibility output can diverge from locale outputs -> Mitigation: build all outputs from the same source graph and validate equivalence for shared delivery controls.
- Client URL rollout can fail for new locale files -> Mitigation: keep `latest.json` v2-compatible and add fallback URL behavior for modern clients.

## Open Questions

- Should Simplified Chinese source be stored as `zh-Hans` only, or should a `zh` alias also be emitted for older tooling?
- Should `latest.json` stay v2 forever, or become an index that points modern clients to locale files after enough versions have upgraded?
- Should locale-specific notice content be split at the same time as release/update announcements, or only update announcements first?
- Should translation review status be a hard production blocker for all non-English locales or a warning with explicit override?

