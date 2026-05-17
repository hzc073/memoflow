## Why

Memo cards currently use proportional press scaling, so taller notes visibly shrink more than shorter notes and create a temporary oversized gap between cards. The interaction feels too heavy for a dense desktop note list where clicking a note should be quiet and nearly unnoticed.

## What Changes

- Replace the memo-list card press feedback with a fixed, very small movement instead of proportional card scaling.
- Keep existing tap, double-tap, long-press, context-menu, hover, focus, and selected-card behavior intact.
- Limit the change to memo list cards; shared `AppPressScale` defaults and unrelated buttons or navigation items will not change.
- Avoid API, persistence, sync, private-extension, subscription, billing, or commercial behavior changes.

## Capabilities

### New Capabilities
- `memo-card-press-feedback`: Defines the expected press feedback behavior for memo list cards.

### Modified Capabilities
- None.

## Impact

- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 10 only. This is a scoped UI interaction change inside `features/memos/widgets` and does not touch known `state -> features`, `application -> features`, or `core -> higher-layer` coupling hotspots.
- Likely affected runtime code:
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_memo_card.dart`
  - Possibly `memos_flutter_app/lib/core/app_motion_widgets.dart` only if a reusable fixed-offset press helper is needed without changing existing defaults.
- Likely affected tests:
  - Focused widget coverage for memo card press feedback if the current test harness can observe transform behavior.
  - `flutter analyze`
  - Focused or full Flutter tests as practical for the UI-only change.
