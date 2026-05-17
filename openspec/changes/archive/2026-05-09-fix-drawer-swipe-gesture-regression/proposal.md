## Why

After upgrading the Flutter app from `v1.0.29` to `v1.0.31`, opening the mobile side drawer by swiping right from the home memo list has become unreliable. This blocks a common navigation path and appears to be related to gesture competition between the drawer open drag and memo-card press feedback.

## What Changes

- Restore responsive right-swipe drawer opening on mobile home/memo-list screens when the drawer is available.
- Ensure memo-card press feedback, tap, long-press, vertical scrolling, and horizontal drawer opening have clear gesture ownership.
- Keep the drawer gesture disabled in existing states where it should not open, such as desktop side-pane layouts and active search.
- Add focused regression coverage for the drawer swipe competing with memo-card press behavior.
- Preserve the active architecture phase `evolve_modularity`; this change touches checklist item `6` because the current memo-list body collaborates with home drawer UI, and it must not add new reverse dependencies from `state`, `application`, or `core` into feature UI.

## Capabilities

### New Capabilities
- `home-drawer-edge-swipe`: Covers mobile home drawer edge/full-width swipe responsiveness and gesture arbitration with memo-list card interactions.

### Modified Capabilities
- None.

## Impact

- Likely affected runtime files:
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_screen_body.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_memo_card.dart`
  - `memos_flutter_app/lib/core/app_motion_widgets.dart`
- Likely affected tests:
  - `memos_flutter_app/test/features/memos/widgets/memos_list_screen_body_test.dart`
  - `memos_flutter_app/test/core/app_motion_widgets_test.dart` if shared press behavior changes.
- No API route, request/response model, backend compatibility, subscription, billing, entitlement, or private-extension behavior is expected to change.
