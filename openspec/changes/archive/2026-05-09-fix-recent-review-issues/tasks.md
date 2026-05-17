## 1. Windows Sub-Window Safety

- [x] 1.1 Locate the quick-input window role or constructor state that identifies Windows desktop sub-window execution.
- [x] 1.2 Gate the quick-input location toolbar action so a Windows sub-window cannot initialize `WindowsEmbeddedMapHost` or `WebviewController`.
- [x] 1.3 Preserve the main-window location picker path without changing normal Windows embedded map behavior.
- [x] 1.4 Add or update a focused desktop guardrail test that fails if quick input can invoke WebView-backed location picking while WebView plugins remain excluded from sub-window registration.

## 2. Dynamic Upload Limit Messaging

- [x] 2.1 Thread the `maxBytes` value from `ShareVideoAttachmentPreparer.confirmCompression` into deferred video confirmation UI.
- [x] 2.2 Replace hardcoded 30 MB compression confirmation and still-too-large copy with limit-aware i18n strings.
- [x] 2.3 Update generated localization output if the project requires regeneration for `strings.g.dart`.
- [x] 2.4 Add or update tests proving a non-30 MiB known upload limit is shown correctly and no fixed 30 MB copy is rendered for that case.

## 3. Modularity And Verification

- [x] 3.1 Keep the implementation out of API request/response models, route adapters, and version compatibility code unless explicit user approval is obtained first.
- [x] 3.2 Ensure the touched implementation adds no new `state -> features`, `application -> features`, or `core -> higher-layer` imports.
- [x] 3.3 Run `flutter analyze` from `memos_flutter_app`.
- [x] 3.4 Run focused tests for desktop sub-window safety and share video upload-limit messaging.
- [x] 3.5 Run `flutter test` from `memos_flutter_app` before marking the change complete.
