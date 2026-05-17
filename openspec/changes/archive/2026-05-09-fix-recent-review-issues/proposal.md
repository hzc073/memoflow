## Why

Recent review found two user-facing regressions in the latest commits: Windows desktop sub-windows can still launch a location picker that depends on an unregistered WebView plugin, and video attachment size prompts still mention a fixed 30 MB limit after backend upload limits became dynamic.

This change fixes those regressions before implementation work continues, while keeping the project in the active `evolve_modularity` architecture phase.

## What Changes

- Prevent Windows desktop sub-windows from invoking location-picker UI that requires `webview_windows` when that plugin is intentionally excluded from sub-window registration.
- Keep the main Windows window location-picker behavior unchanged where the WebView plugin remains registered.
- Pass the resolved attachment upload limit into deferred share video confirmation and failure messaging.
- Replace hardcoded 30 MB user-facing copy with dynamic known-limit copy, and keep generic copy for unknown limits.
- Add focused tests or guardrails for both regressions.
- Preserve current public shell boundaries and avoid API model, route adapter, or version compatibility changes.

## Capabilities

### New Capabilities
- `windows-desktop-subwindow-plugin-safety`: Covers Windows desktop sub-window behavior when plugins are intentionally unavailable in secondary Flutter engines.

### Modified Capabilities
- `attachment-upload-size-policy`: User-facing video compression prompts and failure messages must reflect the known backend upload size limit instead of a hardcoded 30 MB value.

## Impact

- Affected runtime areas:
  - `memos_flutter_app/lib/features/desktop/quick_input/desktop_quick_input_window.dart`
  - `memos_flutter_app/lib/features/location_picker/...`
  - `memos_flutter_app/lib/features/memos/note_input_sheet.dart`
  - `memos_flutter_app/lib/features/share/share_video_attachment_preparer.dart`
  - `memos_flutter_app/lib/i18n/strings*.i18n.yaml`
- Affected tests:
  - Desktop quick-input or Windows sub-window guardrail tests.
  - Share video attachment and note input messaging tests.
  - Localization generated output checks if i18n generation is required.
- API impact: none planned. Existing upload limit resolution behavior is reused.
- Architecture impact:
  - Active phase: `evolve_modularity`.
  - Touched checklist items: item 4, because user-facing upload limit presentation should avoid hiding reusable size-limit formatting logic inside screen code; item 8, because focused guardrails should protect the regression path.
  - The change must not introduce new `state -> features`, `application -> features`, or `core -> higher-layer` dependencies.
