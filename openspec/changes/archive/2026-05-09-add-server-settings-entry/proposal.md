## Why

The app needs a clear place to inspect and, when permitted, update backend-wide Memos limits for memo content length and attachment upload size. These values are server/workspace/instance policies rather than per-user preferences, so putting them inside `UserGeneralSettingsScreen` would blur ownership and permission expectations.

## What Changes

- Add a new `服务器设置` entry under `账号与安全`, near `用户通用设置`, instead of embedding server-wide limits in the user general settings page.
- Add a `服务器设置` screen that can display and edit:
  - `MEMO_RELATED.contentLengthLimit` / `memoRelatedSetting.contentLengthLimit` as memo maximum bytes.
  - `STORAGE.uploadSizeLimitMb` / `storageSetting.uploadSizeLimitMb` as attachment maximum MiB.
- Support version-specific Memos APIs:
  - Memos `0.21`: read attachment upload limit from `GET api/v1/status`; treat memo content limit editing as unsupported because the reference backend uses hardcoded memo limits.
  - Memos `0.22`-`0.24`: use `GET/PATCH api/v1/workspace/settings/MEMO_RELATED` and `GET/PATCH api/v1/workspace/settings/STORAGE`.
  - Memos `0.25+`: use `GET/PATCH api/v1/instance/settings/MEMO_RELATED` and `GET/PATCH api/v1/instance/settings/STORAGE`.
- Make permission handling explicit: elevated APIs that return `401`/`403` should produce disabled or read-only UI states instead of misleading save failures.
- Preserve sibling setting fields when updating a single limit by fetching the current backend setting and merging the changed field before `PATCH`.
- Keep the existing attachment upload size resolver compatible with the new editable settings so any updated limit is reflected in upload pre-check behavior.
- Active architecture phase: `evolve_modularity`. The change touches checklist item 4 because server-limit parsing and write behavior could otherwise be hidden in settings widgets; it also reinforces checklist item 7 by giving touched write paths clear API/model/provider owners.

## Capabilities

### New Capabilities
- `server-settings`: Server/workspace/instance settings entry, display states, permission handling, and editable backend limit behavior.

### Modified Capabilities
- `attachment-upload-size-policy`: Attachment upload size policy must remain consistent with server settings reads/updates and continue treating unreadable storage limits as unknown rather than hard client blocks.

## Impact

- Affected Flutter areas:
  - `memos_flutter_app/lib/features/settings/account_security_screen.dart`
  - New settings screen under `memos_flutter_app/lib/features/settings/`
  - `memos_flutter_app/lib/data/api/memos_api/memos_api_resources.dart`
  - New or extended model/provider code under `memos_flutter_app/lib/data/models` and `memos_flutter_app/lib/state/settings`
- Affected APIs:
  - `GET api/v1/status`
  - `GET/PATCH api/v1/workspace/settings/STORAGE`
  - `GET/PATCH api/v1/workspace/settings/MEMO_RELATED`
  - `GET/PATCH api/v1/instance/settings/STORAGE`
  - `GET/PATCH api/v1/instance/settings/MEMO_RELATED`
  - Legacy `POST api/v1/system/setting` may be considered only for Memos `0.21` attachment limit updates if implementation confirms current auth and compatibility expectations.
- Testing impact:
  - API compatibility tests need coverage for Memos `0.21`, `0.22`/`0.24`, and `0.25+` routes.
  - Permission-denied and unsupported states need focused tests.
  - UI/state tests should verify the screen does not expose editable controls when limits are unavailable or forbidden.
