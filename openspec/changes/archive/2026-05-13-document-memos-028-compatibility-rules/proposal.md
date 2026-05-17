## Why

Memos `0.28.0` removed the old `display_time` API surface and narrowed memo list ordering to `pinned`, `create_time`, `update_time`, and `name`, which breaks the current Explore path that still sends `order_by=display_time desc`. Users now report that Explore cannot load against 0.28 servers, so the client needs explicit compatibility rules before implementation.

## What Changes

- Add a Memos `0.28` compatibility contract that documents the version-specific API changes the Flutter client must honor.
- Extend supported server-version selection and routing rules so `0.28.x` is not silently treated as `0.27.0`.
- Update Explore and Explore-backed random review behavior to use 0.28-supported memo list ordering.
- Update remote memo search fallback behavior so it does not send unsupported `display_time` ordering to 0.28 servers.
- Update timestamp mutation rules so 0.28 requests do not send `displayTime` payload fields or `display_time` update masks.
- Add API compatibility tests that prove 0.28 list, create, and update requests avoid removed fields while preserving existing 0.21-0.27 behavior.
- Active architecture phase: `evolve_modularity`. This change primarily touches checklist items `7`, `8`, `9`, and `10`; it is not expected to touch existing `state -> features`, `application -> features`, `core -> higher-layer`, or shared-widget-logic hotspots. The implementation must preserve those boundaries and add focused compatibility tests as the guardrail improvement.

## Capabilities

### New Capabilities
- `memos-028-compatibility`: Defines the versioned API compatibility rules for Memos `0.28.x`, including removed `display_time` behavior, supported list ordering, and version-selection behavior.

### Modified Capabilities
- `memo-search`: Remote-backed search and list fallback behavior must choose order fields supported by the active Memos server version.
- `memo-time-adjustment`: Remote timestamp mutation behavior must not use removed `display_time` API fields on Memos `0.28.x`.

## Impact

- Affected app code is expected under `memos_flutter_app/lib/data/api`, `memos_flutter_app/lib/state/memos`, `memos_flutter_app/lib/features/explore`, `memos_flutter_app/lib/features/review`, and login/version-selection UI.
- Affected tests are expected under `memos_flutter_app/test/data/api`, plus focused feature or state tests if Explore/random-review ordering is covered outside API compatibility tests.
- No new runtime code should be added outside `memos_flutter_app`.
- No commercial/private-extension behavior is involved.
