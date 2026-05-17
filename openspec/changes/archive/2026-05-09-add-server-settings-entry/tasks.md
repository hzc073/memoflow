## 1. Data Models and API Compatibility

- [x] 1.1 Confirm explicit user approval before editing API-related files under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api`.
- [x] 1.2 Add server settings models for per-field value, source, editability, and unavailable reason under `memos_flutter_app/lib/data/models`.
- [x] 1.3 Add Memos API methods for loading memo content length and attachment upload capacity using the version-specific `0.21`, `0.22`-`0.24`, and `0.25+` routes.
- [x] 1.4 Add Memos API update methods for supported server settings, using merge-before-update for `STORAGE` and `MEMO_RELATED`.
- [x] 1.5 Decide and implement Memos `0.21` attachment write behavior: either support `POST api/v1/system/setting` with tests or mark the field read-only if compatibility is not confirmed.
- [x] 1.6 Classify `401`/`403`, missing endpoints, malformed responses, invalid values, and local-library mode into stable unavailable reasons.

## 2. State and Boundary Ownership

- [x] 2.1 Add a `serverSettingsProvider` or equivalent state owner under `memos_flutter_app/lib/state/settings` for loading, refreshing, and saving server settings.
- [x] 2.2 Keep version routing, response parsing, permission classification, and merge-before-update logic in data/state layers, not in `ServerSettingsScreen`.
- [x] 2.3 After successful attachment limit updates, invalidate or refresh the existing attachment upload size limit state used by upload pre-checks.
- [x] 2.4 Ensure the change preserves dependency direction `features -> state -> data` and introduces no new `state -> features`, `application -> features`, or `core -> higher-layer` imports.

## 3. Settings UI

- [x] 3.1 Add a `服务器设置` row under `账号与安全`, near `用户通用设置`, without changing `UserGeneralSettingsScreen` scope.
- [x] 3.2 Implement `ServerSettingsScreen` with separate memo content length and attachment upload capacity sections.
- [x] 3.3 Render unsupported, permission-denied, unavailable, loading, saving, and saved states per field.
- [x] 3.4 Validate positive integer input locally and avoid sending empty, non-numeric, zero, or negative values.
- [x] 3.5 Add or reuse localization strings for `服务器设置`, memo maximum bytes, attachment maximum capacity, unsupported state, permission-denied state, and save feedback.

## 4. API and State Tests

- [x] 4.1 Add focused API tests for Memos `0.21` server settings behavior, including attachment limit read from `api/v1/status` and the chosen write/read-only behavior.
- [x] 4.2 Add focused API tests for Memos `0.22`-`0.24` workspace settings routes for both `MEMO_RELATED` and `STORAGE`.
- [x] 4.3 Add focused API tests for Memos `0.25+` instance settings routes for both `MEMO_RELATED` and `STORAGE`.
- [x] 4.4 Add tests proving update requests preserve sibling `STORAGE` and `MEMO_RELATED` fields.
- [x] 4.5 Add tests for permission-denied, endpoint-unavailable, malformed response, and non-positive value classification.
- [x] 4.6 Add provider or screen tests that verify disabled/read-only UI states and that `UserGeneralSettingsScreen` does not render server-wide limit controls.

## 5. Verification

- [x] 5.1 Run `flutter test test/data/api --reporter expanded` from `memos_flutter_app`.
- [x] 5.2 Run focused settings/provider tests added for this change.
- [x] 5.3 Run `flutter analyze` from `memos_flutter_app`.
- [x] 5.4 Run `flutter test` from `memos_flutter_app`.
- [x] 5.5 Review touched files for modularity checklist items 4 and 7: shared server settings logic must stay out of widgets and write paths must have clear data/state owners.
