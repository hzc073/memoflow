## 1. Notification State and Settings

- [ ] 1.1 Add RSS feed/source notification preference state.
- [ ] 1.2 Add article notification delivered/skipped metadata for dedupe.
- [ ] 1.3 Add UI controls to enable or disable notifications for RSS feeds or collection RSS sources.

## 2. Notification Planning and Delivery

- [ ] 2.1 Add a notification planner that consumes newly inserted RSS article ids from refresh results.
- [ ] 2.2 Filter eligible articles by feed notification preference and delivery state.
- [ ] 2.3 Schedule local notifications using existing app notification infrastructure.
- [ ] 2.4 Record delivery state after successful notification scheduling.
- [ ] 2.5 Handle notification permission denial without failing RSS refresh.

## 3. Tap Routing

- [ ] 3.1 Add notification payloads for RSS article, feed, and collection context.
- [ ] 3.2 Route notification taps to the RSS article reading/detail context.
- [ ] 3.3 Add fallback behavior when the feed, article, or collection no longer exists.

## 4. Tests and Guardrails

- [ ] 4.1 Add tests for notification eligibility and opt-in behavior.
- [ ] 4.2 Add tests that duplicate refreshes do not duplicate notifications.
- [ ] 4.3 Add tests for tap-routing payload resolution and missing-context fallback.
- [ ] 4.4 Add or tighten guardrails so RSS notification planning stays outside collection widgets.

## 5. Verification

- [ ] 5.1 Run `dart format` on changed Dart files in `memos_flutter_app`.
- [ ] 5.2 Run focused RSS notification tests.
- [ ] 5.3 Run relevant architecture guardrail tests.
- [ ] 5.4 Run `flutter analyze` from `memos_flutter_app`.
- [ ] 5.5 Run `flutter test` from `memos_flutter_app`.
