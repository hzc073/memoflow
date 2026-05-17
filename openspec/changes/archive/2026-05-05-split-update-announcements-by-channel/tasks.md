## 1. Routing Policy

- [x] 1.1 Add a pure update-announcement channel routing policy that maps `AppChannel.play` to no startup fetch and `AppChannel.full` to startup fetch.
- [x] 1.2 Keep the routing policy in a stable non-UI seam so it can be tested without importing `features/updates` dialogs.

## 2. Startup Integration

- [x] 2.1 Apply the routing policy before `UpdateAnnouncementRunner` performs remote update config fetching.
- [x] 2.2 Preserve existing full-channel and desktop startup update announcement behavior.
- [x] 2.3 Keep manual release notes, donors, and notice surfaces unchanged unless they are part of startup update announcement scheduling.

## 3. Tests and Guardrails

- [x] 3.1 Add focused tests proving Play-channel startup routing does not call the remote update config fetch path.
- [x] 3.2 Add focused tests proving full-channel startup routing still allows the remote update config fetch path.
- [x] 3.3 Verify the new policy test target does not introduce new `application -> features` coupling.

## 4. Verification

- [x] 4.1 Run focused update announcement/channel tests from `memos_flutter_app`.
- [x] 4.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 4.3 Run `flutter test` from `memos_flutter_app` before completing the change.
