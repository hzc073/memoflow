## Why

`ServerSettingsScreen` currently shows server-limit values as input values, but after the user clears an editable field there is no lightweight reminder of what the field expects. The memo content length field should guide users with the backend-supported byte range, while the attachment field keeps showing the current server upload limit.

## What Changes

- Add empty-field hint behavior for editable server limit inputs:
  - When the memo limit field is empty while editing, show the theoretical supported byte range as gray placeholder text.
  - When the attachment limit field is empty while editing, show the current server-confirmed attachment limit as gray placeholder text.
  - When the user enters any numeric text, the placeholder disappears through normal `TextField.hintText` behavior.
- Preserve the current low-risk sync behavior: if the field loses focus with no committed input, it should return to the server-confirmed value instead of keeping a blank editable state.
- Keep validation unchanged: empty, zero, non-numeric, or negative values still must not be sent as updates.
- Do not change Memos API routing, server setting models, permission classification, or provider ownership.
- Active architecture phase: `evolve_modularity`. This change touches checklist item 4 only lightly because it refines widget presentation; it must not move shared server-setting parsing, permission, or write logic into UI code. It does not change checklist item 7 write-path ownership.

## Capabilities

### New Capabilities
- `server-settings-empty-field-hints`: Editable server setting inputs display field-specific placeholder guidance only while the input is empty.

### Modified Capabilities
- None

## Impact

- Affected Flutter areas:
  - `memos_flutter_app/lib/features/settings/server_settings_screen.dart`
  - Settings widget tests under `memos_flutter_app/test/features/settings/`
- Affected behavior:
  - Empty editable server setting fields show gray placeholder guidance: memo content length shows supported byte range, attachment upload shows current server limit.
  - Entering text hides the guidance.
  - Blurring an empty field restores the current server value, matching the existing controller sync model.
- No API, persistence, backend, or localization-codegen changes are expected.
