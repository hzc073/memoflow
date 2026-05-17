## 1. Shared Engagement Seam

- [x] 1.1 Confirm existing `MemosApi` reactions/comments methods cover the required loads and mutations; do not edit `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api` unless explicit user approval is obtained.
- [x] 1.2 Extract shared reaction counting, current-user like detection, and summary shaping out of `MemoDetailScreen` into a stable `state/memos` seam.
- [x] 1.3 Add a memoUid-scoped `MemoEngagementController` / provider that loads reactions/comments, deduplicates in-flight requests, and caches snapshots in memory.
- [x] 1.4 Add mutation methods for toggle-like and create-comment that update the cached snapshot after success and roll back optimistic like state on failure.
- [x] 1.5 Add focused unit/provider tests for summary loading, zero-state summary, current-user like detection, and mutation snapshot updates.

## 2. Reusable Engagement UI

- [x] 2.1 Extract the private `_MemoEngagementSection` UI from `memo_detail_screen.dart` into a reusable `MemoEngagementSurface` or equivalent widget under `features/memos/widgets`.
- [x] 2.2 Migrate `MemoDetailScreen` to consume the shared engagement seam and reusable surface while preserving current detail-page behavior.
- [x] 2.3 Add or update detail-screen widget tests to verify likes/comments still render when detail engagement is enabled.

## 3. Home Memo Card Integration

- [x] 3.1 Pass the expanded engagement preference through `MemosListMemoCardContainer` into `MemoListCard` without changing existing card tap, double-tap, long-press, or context-menu semantics.
- [x] 3.2 Render a compact home card engagement summary when the preference is enabled and the memo has existing likes or comments.
- [x] 3.3 Render a compact zero-state engagement affordance when the preference is enabled and the memo has no likes or comments.
- [x] 3.4 Wire the card like control to toggle the current user's like and refresh the visible count/state.
- [x] 3.5 Wire the card comment control to open the shared engagement surface or composer so the user can submit a comment without first opening `MemoDetailScreen`.
- [x] 3.6 Add widget tests for enabled/disabled preference behavior, non-zero engagement display, zero-state display, like action, and comment action entry.

## 4. Localization

- [x] 4.1 Update the `showEngagementInAllMemoDetails` user-visible copy in base and supported locale YAML files so it mentions home memo cards and memo details.
- [x] 4.2 Regenerate `strings.g.dart` using the repository's localization generation path.
- [x] 4.3 Update localization tests or snapshots that assert the previous preference label.

## 5. Modularity Guardrails and Verification

- [x] 5.1 Add or tighten an architecture/test guardrail that keeps engagement loading/mutation logic in the `state/memos` seam and prevents re-embedding shared engagement domain logic inside screen/widget files.
- [x] 5.2 Run `dart format` on changed Dart files in `memos_flutter_app`.
- [x] 5.3 Run focused tests for the new engagement controller and home memo card widgets.
- [x] 5.4 Run `flutter analyze` from `memos_flutter_app`.
- [x] 5.5 Run `flutter test` from `memos_flutter_app`.

## 6. Home Card Detailed Engagement Preview

- [x] 6.1 Update the home-card engagement surface to show concrete liker avatars when likes exist, capped to a small fixed count with an additional-likes indicator.
- [x] 6.2 Update the home-card engagement surface to show the latest one to two comment entries when comments exist.
- [x] 6.3 Add a "view all comments" affordance when the memo has more comments than are previewed, wired to the existing comment surface.
- [x] 6.4 Preserve the compact zero-state like/comment entry for memos without likes or comments.
- [x] 6.5 Preserve detail-page engagement behavior and the existing comment bottom sheet.
- [x] 6.6 Add or update widget tests for liker avatars, recent comment preview, view-all comments, zero-state, preference-disabled behavior, and unchanged detail behavior.
- [x] 6.7 Run `dart format` on changed Dart files in `memos_flutter_app`.
- [x] 6.8 Run focused engagement tests.
- [x] 6.9 Run `flutter analyze` from `memos_flutter_app`.
- [x] 6.10 Run `flutter test` from `memos_flutter_app`.
