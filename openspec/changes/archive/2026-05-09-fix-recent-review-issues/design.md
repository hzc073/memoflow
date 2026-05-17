## Context

The reviewed commits introduced two separate regressions in user-visible flows.

On Windows, sub-window plugin registration now intentionally excludes WebView plugins to avoid multi-engine lifecycle crashes. The quick-input sub-window still exposes the location action, and that action can create `WindowsEmbeddedMapHost`, which requires `webview_windows`. The fix must keep the safer plugin registration behavior while preventing sub-window UI from invoking unavailable plugin surfaces.

For shared video clipping, backend attachment upload limits are now resolved dynamically through existing application/state seams. The compression service uses the resolved limit, but `NoteInputSheet` still renders hardcoded 30 MB copy. The fix should reuse the resolved limit for presentation without changing API models or route adapters.

The active architecture phase is `evolve_modularity`. This change touches feature UI and guardrail tests, and it must keep the touched areas equal or better structured. It should not add new `state -> features`, `application -> features`, or `core -> higher-layer` dependencies.

## Goals / Non-Goals

**Goals:**
- Prevent Windows desktop sub-windows from initializing WebView-backed location-picker UI when WebView plugins are unavailable in that engine.
- Preserve main-window location-picker behavior.
- Make deferred share video confirmation and failure messages reflect the known backend upload limit.
- Add tests or guardrails for the reviewed regressions.
- Keep reusable upload-limit formatting out of ad hoc screen-only constants where practical.

**Non-Goals:**
- Do not reintroduce full WebView plugin registration into Windows sub-windows unless a separate compatibility decision proves it safe.
- Do not change Memos API request/response models, route adapters, or version compatibility logic.
- Do not redesign the location picker or video compression pipeline.
- Do not introduce private/commercial hooks or paid-feature state.

## Decisions

1. Gate unavailable plugin UI at the sub-window feature boundary.

   The Windows runner should continue excluding WebView plugins from sub-window registration. Instead of reversing that native fix, quick-input or the location-picker entry point should detect that the current desktop surface cannot host WebView-backed map UI and avoid launching it. Acceptable behavior is to hide/disable the location action in the quick-input sub-window, or route the action to an existing main-window-safe surface if the codebase already has such a seam.

   Before: the quick-input feature could directly invoke `showLocationPickerSheetOrDialog`, which creates `WindowsEmbeddedMapHost` on Windows. After: the quick-input flow will not instantiate the WebView host from a sub-window engine lacking the plugin.

   Alternative considered: register `WebviewWindowsPlugin` again in every sub-window. Rejected because the reviewed native change intentionally narrowed plugin registration to protect multi-window stability.

2. Keep upload-limit resolution as the source of truth and pass display data downward.

   `ShareVideoAttachmentPreparer` already receives `AttachmentUploadSizeLimit` and passes `maxBytes` to the compression confirmation callback. `NoteInputSheet` should preserve that value for confirmation and still-too-large copy instead of using fixed translation strings that mention 30 MB.

   Before: compression behavior used the dynamic limit, while presentation used hardcoded text. After: both behavior and presentation use the same known limit.

   Alternative considered: leave title strings generic and only show the file size. Rejected because known backend limits are already available and help the user understand why compression is required.

3. Use focused tests and avoid widening layer dependencies.

   Windows protection should be covered by a quick-input/location-picker guardrail or an existing desktop test that verifies WebView-dependent UI is not exposed from sub-window contexts. Upload messaging should be covered by a widget/unit test that verifies a non-30 MiB known limit does not render hardcoded 30 MB copy.

   The implementation should not move feature UI dependencies into `application`, `state`, or `core`. If reusable size formatting is extracted, it should go to an appropriate stable helper already used by attachments/share code, not to a screen file.

## Risks / Trade-offs

- Windows sub-window users may lose direct location picking from quick input if no main-window routing seam exists. -> Mitigation: disable or hide only the unsafe action and keep attachments/text submission unchanged.
- Platform/window-context detection may be brittle if inferred indirectly. -> Mitigation: prefer an existing desktop multi-window argument, window role, provider, or constructor flag already owned by the quick-input surface.
- Localization changes may require regenerating `strings.g.dart`. -> Mitigation: update source YAML and generated output together, then run focused localization/tests.
- Formatting limits as decimal MB vs MiB can confuse users. -> Mitigation: use the app's existing file-size formatting convention and keep behavior tied to bytes from `AttachmentUploadSizeLimit`.
