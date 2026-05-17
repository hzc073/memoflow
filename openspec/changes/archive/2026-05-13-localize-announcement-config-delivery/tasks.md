## 1. Source Model and Build Output

- [x] 1.1 Define the localized source layout under `memoflow_config/update`, including locale content files and language-neutral delivery metadata.
- [x] 1.2 Update the config build design so all locale outputs are generated from one source graph.
- [x] 1.3 Preserve a v2-compatible `latest.json` output for old clients.
- [x] 1.4 Explicitly reject or ignore v1-only source/output shapes in the localized delivery pipeline.
- [x] 1.5 Add validation that localized content files contain only their declared locale content.

## 2. Locale Selection and Fallback

- [x] 2.1 Define the app locale to config locale mapping for `zh-Hans`, `zh-Hant-TW`, `en`, `ja`, `de`, `pt-BR`, and `ko`.
- [x] 2.2 Add client-side design coverage for fetching `latest.<locale>.json` before falling back.
- [x] 2.3 Require modern clients to reject locale configs whose top-level `locale` does not match the requested locale.
- [x] 2.4 Define English fallback behavior when requested locale content is missing.
- [x] 2.5 Define the terminal behavior when English fallback content is missing: the candidate is not shown.

## 3. Local Config Manager and AI Translation

- [x] 3.1 Add local-only AI provider configuration design for `memoflow_config/config` without committing secrets or publishing provider settings.
- [x] 3.2 Add an AI draft translation workflow from Chinese source content to target locale files.
- [x] 3.3 Store translation metadata such as `source_locale`, `source_hash`, and review status.
- [x] 3.4 Mark translated files stale when source content changes.
- [x] 3.5 Block or warn on publish when target locale content is AI-generated but not reviewed.

## 4. App Integration and Modularity

- [x] 4.1 Keep locale URL selection and fallback rules in `data/updates` or `application/updates`, not feature widgets.
- [x] 4.2 Preserve the existing `AnnouncementPresenter` boundary; do not add direct `application/updates -> features/updates` dialog imports.
- [x] 4.3 Extract shared locale/content resolution helpers if both startup delivery and Debug preview need them.
- [x] 4.4 Add or tighten guardrail coverage if implementation touches existing announcement dependency hotspots.

## 5. Verification

- [x] 5.1 Validate localized source files and generated locale outputs.
- [x] 5.2 Verify v2-compatible `latest.json` remains parseable by the current v2 compatibility model.
- [x] 5.3 Verify v1-only configs are not accepted as localized delivery inputs.
- [x] 5.4 Verify missing target locale content falls back to English.
- [x] 5.5 Verify missing English fallback suppresses the candidate rather than showing a wrong language.
- [x] 5.6 Run focused Flutter tests for update config parsing/service behavior when implementation begins.
- [x] 5.7 Run focused local config manager/build tests when `memoflow_config` implementation begins.
- [x] 5.8 Run `openspec status --change "localize-announcement-config-delivery"` and resolve any artifact issues.
