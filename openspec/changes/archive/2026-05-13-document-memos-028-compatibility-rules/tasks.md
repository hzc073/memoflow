## 1. Version Model And Routing

- [x] 1.1 Add `MemoApiVersion.v028` with `0.28.0` normalization, parsing, labels, and probe-order coverage.
- [x] 1.2 Add the `0.28.0` facade entry points for authenticated, unauthenticated, session-authenticated, and password sign-in clients.
- [x] 1.3 Add `0.28.0` to login/manual server-version selection and update related validation copy if needed.
- [x] 1.4 Update version-family switch statements that currently group `0.25+` behavior so `v028` is handled explicitly.

## 2. Request Compatibility Rules

- [x] 2.1 Add a data-layer compatibility seam for memo list ordering that maps Explore/search desired ordering to fields supported by the active server version.
- [x] 2.2 Route Explore memo loading through the ordering compatibility seam instead of passing raw `display_time desc`.
- [x] 2.3 Route Explore-backed random review loading through the ordering compatibility seam.
- [x] 2.4 Route remote memo search fallback through the ordering compatibility seam.
- [x] 2.5 Update create-memo request shaping so Memos `0.28.x` does not send `displayTime`.
- [x] 2.6 Update update-memo request shaping so Memos `0.28.x` does not send `display_time` update masks or `displayTime` body fields.

## 3. Tests And Guardrails

- [x] 3.1 Extend API version parsing/facade tests to cover `0.28.0`.
- [x] 3.2 Add list-memo request compatibility coverage proving Memos `0.28.x` uses supported `orderBy` fields and never sends `display_time desc`.
- [x] 3.3 Extend create-memo compatibility tests proving Memos `0.28.x` omits `displayTime` while existing `0.21` through `0.27` expectations remain valid.
- [x] 3.4 Extend update-memo compatibility tests proving Memos `0.28.x` omits `display_time` and `displayTime` while existing `0.21` through `0.27` expectations remain valid.
- [x] 3.5 Add targeted tests for Explore/random-review/search ordering call sites if the API request tests do not cover those paths directly.
- [x] 3.6 Confirm no new `state -> features`, `application -> features`, or `core -> state|application|features` imports were introduced.

## 4. Verification

- [x] 4.1 Run `flutter test test/data/api --reporter expanded` from `memos_flutter_app`.
- [x] 4.2 Run focused feature/state tests added or changed for Explore, random review, or search ordering.
- [x] 4.3 Run `flutter analyze` from `memos_flutter_app`.
- [x] 4.4 Run `flutter test` from `memos_flutter_app` before release or PR handoff.
