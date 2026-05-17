## Context

Current settings navigation exposes `用户通用设置` from `AccountSecurityScreen`, and that page only updates `UserSetting.GENERAL` fields such as `locale` and `memoVisibility`. The requested memo byte limit and attachment upload capacity are not user settings in the reference Memos backend; they are instance/workspace/system policies with elevated write permissions.

The active architecture phase is `evolve_modularity`. This change touches `features/settings`, `state/settings`, `data/models`, and `data/api/memos_api`. The relevant modularity risk is checklist item 4: backend version mapping, permission classification, and merge-before-update logic should not be embedded in a widget. The touched write path should keep checklist item 7 strong by giving API mutations a clear owner.

Before:

```text
UserGeneralSettingsScreen
  -> memosApi.updateUserGeneralSetting(...)
  -> users/*/setting or users/*/settings/GENERAL
```

After:

```text
AccountSecurityScreen
  -> ServerSettingsScreen
      -> serverSettingsProvider
          -> memosApi.getServerSettings()
          -> memosApi.updateServerMemoLimit(...)
          -> memosApi.updateServerAttachmentLimit(...)
              -> version-specific workspace/instance/system routes
```

The dependency direction remains `features -> state -> data`. No `state -> features`, `application -> features`, or `core -> higher layer` dependency is needed.

## Goals / Non-Goals

**Goals:**

- Add a standalone `服务器设置` entry under `账号与安全`, near `用户通用设置`.
- Show memo content length limit in bytes and attachment upload size limit in MiB when the active server supports reading them.
- Allow editing only when the API supports the setting and the backend accepts the authenticated user.
- Support Memos `0.21`, `0.22`-`0.24`, and `0.25+` route families.
- Preserve sibling fields in `STORAGE` and `MEMO_RELATED` settings when updating one field.
- Keep the existing attachment upload pre-check policy aligned after a successful attachment limit update.

**Non-Goals:**

- Do not add arbitrary instance setting management for unrelated keys such as `GENERAL`, `TAGS`, `NOTIFICATION`, or `AI`.
- Do not change `UserGeneralSetting` semantics or store server-wide fields in `users/*/settings/GENERAL`.
- Do not add commercial/private extension hooks.
- Do not guarantee that reverse proxy upload limits can be discovered or edited.
- Do not implement memo content limit editing for Memos `0.21`, because the reference backend uses hardcoded memo length limits.

## Decisions

### Decision 1: Add `服务器设置` as a separate settings entry

Use `AccountSecurityScreen` to add a new row below `用户通用设置`. The new page title and row label should be `服务器设置`.

Rationale: the settings affect the backend instance/workspace, not the current user. Keeping the entry separate avoids implying that ordinary users can set personal upload or memo limits.

Alternative considered: append the fields to `UserGeneralSettingsScreen`. This was rejected because it mixes `UserSetting.GENERAL` with instance/workspace settings and would make permission-denied behavior look like a broken personal preference.

### Decision 2: Represent each setting as a value plus capability state

Introduce a small model such as `ServerSettingsSnapshot` with per-field states:

```text
ServerSettingsSnapshot
├─ memoContentLimit: ServerSettingValue<int>
└─ attachmentUploadLimit: ServerSettingValue<int>

ServerSettingValue<T>
├─ value
├─ supported
├─ editable
├─ unavailableReason
└─ source
```

Suggested unavailable reasons: `localLibrary`, `unsupportedVersion`, `permissionDenied`, `endpointUnavailable`, `invalidResponse`, `requestFailed`, and `nonPositiveLimit`.

Rationale: memo limit and attachment limit can have different support and permission states on the same server. A single loading/error state would either hide useful information or over-enable controls.

Alternative considered: use nullable integers only. This was rejected because `null` cannot distinguish unsupported, forbidden, malformed, and not-yet-loaded states.

### Decision 3: Keep version routing inside `MemosApi`

Add server settings methods to `memos_api_resources.dart` or a new `memos_api_server_settings.dart` part:

- `Future<ServerSettingsSnapshot> getServerSettings()`
- `Future<ServerSettingValue<int>> getMemoContentLimit()`
- `Future<ServerSettingValue<int>> getAttachmentUploadLimitForSettings()`
- `Future<ServerSettingsSnapshot> updateServerMemoContentLimitBytes(int bytes)`
- `Future<ServerSettingsSnapshot> updateServerAttachmentUploadLimitMiB(int mib)`

Version behavior:

| Server flavor | Memo limit read/write | Attachment limit read/write |
|---|---|---|
| `v0_21` | unsupported | read `GET api/v1/status`; write `POST api/v1/system/setting` with `max-upload-size-mib` if implementation confirms auth compatibility |
| `v0_22`-`v0_24` | `GET/PATCH api/v1/workspace/settings/MEMO_RELATED` | `GET/PATCH api/v1/workspace/settings/STORAGE` |
| `v0_25Plus` / `unknown` | `GET/PATCH api/v1/instance/settings/MEMO_RELATED` | `GET/PATCH api/v1/instance/settings/STORAGE` |

Rationale: route selection already lives in `MemosApi` for attachment uploads, memo routes, notifications, and user settings. Keeping the server settings route matrix there prevents screens/providers from duplicating version logic.

Alternative considered: add a repository that constructs raw Dio requests. This was rejected because the existing API facade already owns server flavor detection and request helpers.

### Decision 4: Use merge-before-update for structured settings

For `workspace/settings/STORAGE`, `workspace/settings/MEMO_RELATED`, `instance/settings/STORAGE`, and `instance/settings/MEMO_RELATED`, updates should:

1. `GET` the current setting.
2. Parse the relevant nested setting map.
3. Replace only the requested field.
4. `PATCH` the full setting object back.
5. Re-read or parse the response into the snapshot model.

Rationale: these settings contain other fields. Sending only `uploadSizeLimitMb` or `contentLengthLimit` can clear sibling fields on older backends because the backend `Upsert...Setting` replaces the setting value. This is especially important for `STORAGE`, which can include local/S3 configuration.

Alternative considered: rely on `update_mask`. This was rejected because `0.22`-`0.24` workspace settings have no `update_mask`, and `0.25+` instance service currently accepts but does not apply `update_mask` in the reference backend.

### Decision 5: Permission is discovered from API responses

The current app `User` model does not persist role information. The page should not depend on guessed Host/Admin status. Instead:

- `401`/`403` while reading a setting marks that field as `permissionDenied`.
- `401`/`403` while saving shows a permission message and refreshes state.
- Readable but non-writable settings render as disabled controls with explanatory helper text.

Rationale: backend permission rules differ across versions (`RoleHost` in older versions, `RoleAdmin` in newer ones). API response classification is more reliable than stale role assumptions.

Alternative considered: extend `User` to store role and gate UI preemptively. This adds broader model and session blast radius and still cannot cover token scopes or server-specific authorization.

### Decision 6: Reuse and extend attachment upload policy behavior

The existing `getAttachmentUploadSizeLimit()` behavior should remain compatible:

- Unknown storage limits still do not block uploads.
- Successful updates from `服务器设置` should invalidate any provider/cache that feeds upload pre-checks.
- If helper parsing can be shared, extract it into data-layer helpers inside `memos_api_resources.dart` or adjacent API code, not into widgets.

Rationale: editing server settings should not regress the current upload pre-check behavior or introduce duplicate parsing code.

## Risks / Trade-offs

- [Risk] `STORAGE` settings may contain sensitive S3 fields. → Mitigation: never log raw setting bodies; merge fields in memory; preserve write-only credential fields by leaving existing values intact and relying on backend preservation behavior where available.
- [Risk] `0.21` attachment writes use a legacy `POST api/v1/system/setting` shape that differs from workspace/instance settings. → Mitigation: cover with focused API tests and show unsupported or permission-denied state if the endpoint fails.
- [Risk] Reading `STORAGE` may be forbidden for non-admin users, so the page could show only partial data. → Mitigation: model per-field availability and allow `MEMO_RELATED` to load independently.
- [Risk] The backend may reject low limits or normalize values. → Mitigation: validate positive integers locally, then display the server-returned/refetched value after saving.
- [Risk] Adding a new settings page can add UI strings in multiple locales. → Mitigation: add localization keys for labels/helper text and keep fallback text concise.
- [Risk] This touches API compatibility code, which has explicit repository guardrails. → Mitigation: require user approval before implementation and run focused `test/data/api` coverage before broader checks.

## Migration Plan

No data migration is required. The change adds a new UI entry and API methods. Existing attachment upload size resolution remains valid.

Implementation rollout:

1. Add data models and API route methods with tests.
2. Add provider/state layer for server settings.
3. Add `ServerSettingsScreen` and account/security entry.
4. Wire refresh/invalidation after successful saves.
5. Run focused API tests, then `flutter analyze` and `flutter test`.

Rollback is straightforward: remove the entry and screen while keeping any harmless data-layer helpers if they are already covered and reused by existing upload policy.

## Open Questions

- Should Memos `0.21` attachment limit editing be enabled by default via `POST api/v1/system/setting`, or should it be read-only until tested against a real `0.21` deployment?
- What exact Chinese/English copy should the UI use for permission-denied and unsupported settings? The implementation can choose concise wording if no product copy is provided.
