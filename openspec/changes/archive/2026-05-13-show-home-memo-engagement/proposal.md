## Why

The existing engagement preference should cover both memo details and home memo cards. The home list should not only show numeric engagement counts; when a memo already has engagement, the card should make that engagement concrete by showing liker avatars and recent comment content, similar to the Explore surface.

## What Changes

- Home memo cards display concrete liker avatars when likes exist.
- Home memo cards show the latest one to two comment entries when comments exist.
- When more comments exist than are previewed, the card shows a "view all comments" affordance that opens the existing engagement/comment surface.
- Memos without likes or comments keep the compact like/comment entry so users can still interact directly from the card.
- The existing `showEngagementInAllMemoDetails` setting remains the gate for both home cards and memo details.
- Memo detail behavior and the existing comment bottom sheet remain unchanged.
- Engagement loading and mutation logic stays in the `state/memos` seam; feature widgets consume that seam instead of owning API calls.

## Capabilities

### New Capabilities

- `home-memo-engagement`: Defines home memo card engagement previews and actions.

### Modified Capabilities

- `app-localization`: Adds user-visible copy for the home-card "view all comments" affordance while preserving the existing preference key.

## Impact

- Affected UI: `memos_flutter_app/lib/features/memos/widgets/memo_engagement_surface.dart` and existing home-card wiring.
- Affected state/data: no server API contract changes; the existing memo engagement provider remains the loading and mutation seam.
- Affected localization: supported locale YAML files and generated `strings.g.dart`.
- Testing impact: widget coverage for liker avatars, recent comment previews, view-all comments, zero-state, disabled preference behavior, and detail regression.
- Architecture phase: `evolve_modularity`; this change keeps shared engagement behavior out of screen/widget-only logic.
