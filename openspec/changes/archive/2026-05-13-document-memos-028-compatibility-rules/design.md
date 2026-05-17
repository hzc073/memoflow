## Context

The current client supports Memos `0.21` through `0.27` with version-specific API facades and route adapters. The active architecture phase is `evolve_modularity`; this change is expected to touch data-layer API compatibility code, state-layer search/sync call sites, and feature-layer Explore/random-review call sites.

Reference Memos `0.28.0` changes relevant to this client:
- `Memo.display_time` is reserved in `proto/api/v1/memo_service.proto`.
- `ListMemos.order_by` supports `pinned`, `create_time`, `update_time`, and `name`; `display_time desc` is rejected.
- `UpdateMemo` rejects `display_time` update masks.
- The web reference now uses `create_time` or `update_time` as the selectable time basis.

Current client risks:
- `ExploreScreen` and Explore-backed random review pass `display_time desc`.
- remote search fallback also passes `display_time desc`.
- create/update timestamp compatibility still treats `displayTime` and `display_time` as valid for the modern `0.25+` family.
- login/manual version selection cannot select `0.28.0`.

Dependency direction before the change:
- feature screens call `MemosApi` directly for Explore lists.
- state search/sync code calls `MemosApi` directly.
- API version and route compatibility live under `memos_flutter_app/lib/data/api`.

Dependency direction after the change:
- feature and state call sites still depend only on the existing API/provider seams.
- Memos `0.28` capability decisions live in `memos_flutter_app/lib/data/api` rather than in UI widgets.
- no new `state -> features`, `application -> features`, or `core -> higher-layer` dependencies are introduced.

This change does not directly edit a known coupling hotspot. The scoped modularity improvement is guardrail coverage: API compatibility tests must lock the 0.28 behavior so future code cannot reintroduce removed `display_time` routes.

## Goals / Non-Goals

**Goals:**
- Add first-class Memos `0.28.x` version support.
- Make Explore work against Memos `0.28.x` by avoiding unsupported ordering.
- Keep remote search and random review compatible with the active server version.
- Prevent create/update requests from sending removed `displayTime` or `display_time` fields to Memos `0.28.x`.
- Preserve existing behavior for Memos `0.21` through `0.27`.
- Add tests that document the 0.28 compatibility rules.

**Non-Goals:**
- Redesign memo timeline semantics across the local database.
- Remove local `display_time` persistence; the app may continue to use local adjusted time for offline/timeline behavior.
- Add commercial/private extension hooks.
- Change Memos server behavior.
- Broaden unrelated modularity refactors.

## Decisions

### Decision: Add an explicit `MemoApiVersion.v028`

Add `v028` to the supported version enum, parser, probe order, facade dispatch, login version selector, and any force-delete/support switch that groups `0.25+` versions.

Rationale: treating `0.28.x` as `0.27.0` hides an API incompatibility. An explicit version lets tests verify the removed fields and lets users choose the correct backend during sign-in.

Alternative considered: infer `0.28.x` through the existing `v0_25Plus` profile only. This keeps route selection mostly working but cannot express the removed `display_time` behavior cleanly in versioned API tests.

### Decision: Centralize supported memo list ordering in the API compatibility layer

Add a data-layer helper or capability flag that maps the desired memo order to a server-supported `orderBy` value. For `0.28.x`, Explore-like and remote-search fallback calls must use `create_time desc` or another supported field. For existing versions, preserve current behavior unless tests identify a safe broader migration.

Rationale: the unsupported `display_time desc` appears in multiple surfaces. A single compatibility rule avoids scattering raw version checks through `ExploreScreen`, random review providers, and search coordinators.

Alternative considered: replace every `display_time desc` literal with `create_time desc`. This would likely fix 0.28 but could change behavior for older versions where adjusted display time still matters.

### Decision: Preserve local adjusted-time semantics while adapting remote timestamp API calls

Keep local `display_time` storage and local effective display time behavior. For Memos `0.28.x`, remote create/update requests must use supported `createTime` and/or `updateTime` fields and must not send `displayTime` body fields or `display_time` update masks.

Rationale: local display time is part of existing app behavior and database semantics. The compatibility break is the remote API contract, not the local timeline model.

Alternative considered: remove local display time entirely. That is too broad for this fix and would affect imports, timeline ordering, collections, and local-library behavior.

### Decision: Use focused compatibility tests as the modularity guardrail

Add or extend tests under `memos_flutter_app/test/data/api` to verify 0.28 list/create/update requests. Add targeted tests for Explore/random-review/search order selection if the compatibility helper is outside the API facade.

Rationale: this change does not touch a known reverse-dependency hotspot, so a focused behavioral guardrail is the right evolve-phase improvement.

Alternative considered: add a broad architecture guardrail. That would not directly catch the 0.28 regression and would be less useful than request-shape tests.

## Risks / Trade-offs

- [Risk] `create_time desc` changes remote ordering for users who relied on adjusted display time on older servers. -> Mitigation: gate the new order field to `0.28.x` unless broader tests justify changing older versions.
- [Risk] Some timestamp adjustment flows may partially sync to 0.28 because `display_time` has no remote equivalent. -> Mitigation: preserve local adjusted time and surface remote sync limitations through existing sync error/state behavior.
- [Risk] Probe coverage may create/delete test memos using the wrong timestamp fields. -> Mitigation: include 0.28 in compatibility tests before enabling it in login selection.
- [Risk] Version-specific rules could be duplicated in feature code. -> Mitigation: keep compatibility decisions in `data/api` and route feature/state code through that seam.

## Migration Plan

1. Add the 0.28 API version and route/profile wiring.
2. Add request-shape tests for 0.28 list, create, and update behavior.
3. Add an order compatibility seam and move Explore/random-review/search fallback call sites to it.
4. Update timestamp request shaping for 0.28.
5. Run focused API tests, then broader `flutter analyze` and `flutter test` before release.

Rollback is straightforward: remove `v028` from selectable/probe versions if 0.28 compatibility must be temporarily disabled. Existing 0.21-0.27 paths should remain unchanged.

## Open Questions

- Should the 0.28 default ordering be `create_time desc` to match the Memos web default, or should the app expose a user-facing choice between `create_time` and `update_time` later?
- Should remote timestamp adjustment on 0.28 update both `create_time` and `update_time`, or only the field that best preserves current app display semantics?
