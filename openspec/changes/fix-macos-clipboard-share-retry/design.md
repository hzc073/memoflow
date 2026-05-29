## Context

Clipboard URL clipping currently runs as a short burst of checks from `app.dart` when the app becomes ready, resumes, or observes preference/session/library changes. When a URL is detected, `app.dart` records the normalized URL as prompted, marks the current burst handled, asks for confirmation, and delegates the share launch to `StartupCoordinator`.

The share flow can then run as a macOS desktop share task window, a quick clip sheet, or the main-window share preview fallback. While any share flow is active, `StartupCoordinator.shouldDeferHeavyStartupWork` causes future clipboard checks to skip. This is correct while a clipping task owns the UI, but there is no explicit handoff back to clipboard detection after the task fails, completes, or is canceled. If the user copies a different URL while the app remains foregrounded, no lifecycle trigger schedules a new clipboard burst.

The active architecture phase is `evolve_modularity`. The touched hotspot is the existing `application -> features` share flow, because `StartupCoordinator` already coordinates feature-level share UI. The change will keep the dependency direction unchanged and improve the touched area through focused callback seams and tests rather than adding new direct imports or moving retry policy into widgets.

## Goals / Non-Goals

**Goals:**
- Let users copy URL B and receive a new clipboard clipping prompt after URL A fails, completes, or is canceled, without restarting or backgrounding the app.
- Keep same-URL duplicate suppression so unchanged clipboard content does not prompt repeatedly.
- Release desktop share task active state on result and cancellation paths so stale task state does not block future clipboard checks.
- Add focused tests for retry scheduling, active-flow suppression, duplicate suppression, and desktop task cleanup.
- Preserve current startup, resume, share capture, quick clip recovery, and desktop task-window behavior except for retryability.

**Non-Goals:**
- Do not introduce continuous clipboard polling.
- Do not change server API models, adapters, or compatibility behavior.
- Do not redesign the share capture engine, parser behavior, or quick clip persistence model.
- Do not enable desktop share task windows on Windows or Linux.
- Do not add private, paid, subscription, entitlement, StoreKit, or commercial logic.

## Decisions

### Decision 1: Add a share-flow completion callback instead of polling

When `StartupCoordinator` finishes or cancels a share flow and no desktop share task remains active, it should notify an injected callback such as `onShareFlowReleased`. `App` can bind that callback to `_scheduleClipboardShareChecks(source: 'share_flow_released')`.

Rationale: The event that matters is not time passing; it is the share-flow lock being released. This avoids continuous polling and keeps `StartupCoordinator` as the owner of share-flow lifecycle state.

Alternative considered: Poll the clipboard every few seconds while the app is foregrounded. Rejected because it increases platform clipboard reads, risks repeated prompts, and hides the lifecycle bug instead of fixing the release point.

### Decision 2: Keep duplicate suppression URL-based and update it only for actual prompts

The existing `_lastClipboardPromptedUrl` should continue suppressing prompts for the same normalized URL. The retry path should schedule a new burst after flow release, but the burst should still skip if the clipboard still contains the same URL. If the clipboard contains a different normalized URL, it should prompt.

Rationale: The reported workflow changes URL A to URL B. Re-prompting for A immediately after a failure would be noisy; detecting B is the desired behavior.

Alternative considered: Clear `_lastClipboardPromptedUrl` whenever clipping fails. Rejected because it would make failed A prompt again even if the user has not copied new content.

### Decision 3: Make desktop task cleanup idempotent

Desktop share task result and cancellation handling should remove the task id, refresh `_shareFlowActive`, run existing quick clip recovery/sync flush work, and notify the release callback only when all active desktop share tasks are gone. Unknown or invalid request ids should remain ignored and should not release unrelated active tasks.

Rationale: macOS share task windows use request ids to isolate one-shot tasks. Releasing the global share lock too early could allow clipboard prompts while another share window is still active.

Alternative considered: Always set `_shareFlowActive` false on any cancel/result method call. Rejected because it would break multiple active share windows and could mix user workflows.

### Decision 4: Preserve dependency direction and add tests as the modularity improvement

Before the change:
- `app.dart` owns clipboard detection scheduling and delegates share launches to `StartupCoordinator`.
- `StartupCoordinator` owns share-flow lifecycle and already imports share feature types/UI through existing partial files.
- Desktop share task windows communicate back through the existing desktop window IPC seam.

After the change:
- `app.dart` remains the clipboard scheduling owner and receives a lifecycle callback from `StartupCoordinator`.
- `StartupCoordinator` remains the share-flow lifecycle owner and exposes a narrow callback instead of importing clipboard detector code.
- Desktop share task windows continue using the existing result/cancel IPC seam.

This keeps the existing dependency direction unchanged while adding a testable seam that prevents future regressions in clipboard retry behavior.

## Risks / Trade-offs

- [Risk] A release callback could schedule a clipboard check before the failed share UI fully disappears. → Mitigation: schedule through the existing delayed burst mechanism, which already performs immediate and delayed checks and respects `shouldDeferHeavyStartupWork`.
- [Risk] Re-checking after every share completion may show a prompt for a different URL that the user copied during clipping. → Mitigation: this is the desired retry behavior; same-URL suppression remains in place.
- [Risk] A stale desktop share task might still block retries if the sub-window crashes without sending cancel. → Mitigation: keep existing cancel-on-dispose behavior and add tests around cancel/result cleanup; consider a later task-timeout change only if runtime evidence shows sub-window crashes bypass dispose.
- [Risk] More logic could accumulate in `app.dart`. → Mitigation: limit `app.dart` to scheduling clipboard checks and keep share-flow release policy in `StartupCoordinator`.

## Migration Plan

1. Add the narrow share-flow release callback wiring.
2. Use the callback from every terminal share-flow path: quick clip sheet completion/cancel/failure, main-window preview completion/cancel, and desktop share task result/cancel when the active task map becomes empty.
3. Add focused tests before broad manual verification.
4. Run `flutter analyze`, focused share/startup tests, OpenSpec validation, and `git diff --check`.

Rollback is straightforward: remove the callback wiring and tests. No data migration or API migration is required.

## Open Questions

- Should a future change add a timeout for desktop share task windows that disappear without sending cancel? This proposal does not add a timeout unless implementation discovers an existing reliable visibility signal that can be used safely.
