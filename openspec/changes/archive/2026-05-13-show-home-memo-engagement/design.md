## Context

The setting `showEngagementInAllMemoDetails` now gates engagement rendering in both memo details and home memo cards. The first implementation added a compact home-card surface with numeric like/comment counts and direct actions.

The requirement has been refined: home memo cards should look closer to the Explore engagement presentation. Cards with engagement should show concrete liker avatars and recent comment content, while cards without engagement should keep the compact entry points for liking and commenting. The existing comment bottom sheet / shared engagement surface must remain the comment interaction surface.

## Goals / Non-Goals

**Goals:**
- Show up to a small fixed number of concrete liker avatars on home memo cards.
- Indicate additional likes beyond the visible avatars with a compact text affordance.
- Show the latest one to two comment entries on home memo cards.
- Show a "view all comments" affordance when more comments exist than are previewed, opening the existing comment surface.
- Keep the zero-state compact like/comment entry when there are no likes or comments.
- Keep detail page behavior and the current comment surface unchanged.

**Non-Goals:**
- Do not change the Memos server API contract.
- Do not persist reaction/comment counters into the memo SQLite row.
- Do not embed the full comment thread inline in each home card.
- Do not introduce subscription, billing, entitlement, paywall, or private/commercial logic.

## Decisions

1. Reuse `MemoEngagementController` as the single loading and mutation seam.
   - Home cards should consume the same snapshot used by details instead of adding API calls to widgets.

2. Extend the compact card rendering mode rather than creating a second engagement implementation.
   - The card mode can display detailed previews, while the detail mode keeps the full interaction layout.

3. Cap home-card inline content.
   - Visible liker avatars: at most 5.
   - Visible comments: latest 1 to 2 entries.
   - Additional comments open the existing comment surface instead of expanding the full thread inline.

4. Preserve the zero-state compact affordance.
   - If a memo has no likes and no comments, the card still shows compact like/comment actions.

5. Preserve the existing setting key.
   - The user-visible copy already describes home cards and details; no key migration is needed.

## Risks / Trade-offs

- More visible content increases card height variability. The mitigation is strict caps on avatars and comments.
- Home cards may trigger more engagement loads. The mitigation remains memoUid-scoped caching and in-flight request dedupe.
- Comment previews can contain long text. The mitigation is short max lines and overflow handling in the card preview.

## Migration Plan

1. Update the home-card engagement surface to render avatars and comment previews when snapshot data exists.
2. Keep the existing compact zero-state path.
3. Keep detail mode and the bottom-sheet comment composer unchanged.
4. Add focused widget tests for avatar rendering, comment previews, view-all comments, zero-state, and preference-disabled behavior.
5. Re-run formatting, focused tests, `flutter analyze`, and `flutter test`.
