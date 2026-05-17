## 1. UI Behavior

- [x] 1.1 Review `ServerSettingsScreen` and `_LimitSection` to confirm the current controller sync behavior restores server values when fields lose focus.
- [x] 1.2 Add field-specific hint text for known editable memo and attachment limit fields: memo uses byte range, attachment uses current server limit.
- [x] 1.3 Wire the hint through `TextField` decoration so the hint appears only when the input is empty and disappears when the user enters text.
- [x] 1.4 Keep unavailable, unsupported, permission-denied, read-only, saving, and saved-state messages unchanged.

## 2. Widget Coverage

- [x] 2.1 Add or extend focused settings widget tests to verify clearing the memo limit field shows the supported byte-range hint.
- [x] 2.2 Add or extend focused settings widget tests to verify clearing the attachment limit field shows the current MiB-limit hint.
- [x] 2.3 Verify entering numeric text hides the placeholder behavior and does not call save during text entry.
- [x] 2.4 Verify clearing a field and moving focus away restores the server-confirmed value without sending an update request.
- [x] 2.5 Verify unavailable or permission-denied fields do not invent placeholder limit values.

## 3. Verification

- [x] 3.1 Run the focused settings test file that covers `ServerSettingsScreen`.
- [x] 3.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 3.3 Review the touched files for modularity: the change must remain UI presentation only and must not move API routing, parsing, permission classification, or write-path ownership into widgets.
