## Context

`build_apk.ps1` and `build_windows.ps1` both run `dart run tool/sync_splash_tokens.dart --check` before package builds. This is intentionally strict: generated splash outputs must match `tool/splash_tokens.yaml` before local packaging or GitHub release packaging proceeds.

The current failure is caused by drift between the splash token source and generated outputs. The user wants the old logo value, `assets/splash/splash_logo_native.png`, to remain the startup logo source rather than `assets/images/streamline--wind-flow-1-remix.png`. The same sync pass may also reconcile other token drift such as `startup_visible_min_ms`.

This change is tooling/configuration scoped. It does not alter API routes, data models, private extension hooks, commercial behavior, or app architecture boundaries. The active architecture phase remains `evolve_modularity`; no known coupling hotspot is touched.

## Goals / Non-Goals

**Goals:**
- Restore `tool/splash_tokens.yaml` so `logo_asset` uses `assets/splash/splash_logo_native.png`.
- Regenerate generated splash outputs from the token source so the existing `--check` preflight passes.
- Keep local and GitHub release packaging protected by the same splash-token consistency guard.
- Improve script/workflow diagnostics enough that future failures are understandable from CI logs.

**Non-Goals:**
- Do not redesign the splash screen visual system.
- Do not bypass or remove `sync_splash_tokens.dart --check`.
- Do not introduce new runtime dependencies or app-layer abstractions.
- Do not touch API compatibility code or tests.

## Decisions

1. Keep `tool/splash_tokens.yaml` as the source of truth.
   - Rationale: the existing generator already derives Dart, Android XML, and `flutter_native_splash.yaml` from this file.
   - Alternative considered: manually edit only `splash_tokens.g.dart`; rejected because CI would still fail and generated files would drift again.

2. Preserve the strict pre-build check in PowerShell scripts.
   - Rationale: failing before `flutter build` catches stale generated files early and prevents inconsistent release artifacts.
   - Alternative considered: auto-run the generator during packaging; rejected because it would make CI mutate the checkout and hide uncommitted generated changes.

3. Improve failure guidance instead of moving validation into GitHub-only logic.
   - Rationale: local and CI behavior should remain the same. The GitHub workflow should call the project script, while the script owns the project-specific preflight.
   - Alternative considered: duplicate token checks inside `.github/workflows/build_release_apk.yml`; rejected because duplicated logic would be harder to keep aligned with Windows/local packaging.

4. Treat generated splash output updates as part of the change.
   - Rationale: the repo must commit generated outputs so `--check` passes on a clean GitHub runner.
   - Alternative considered: rely on each developer or runner to regenerate outputs locally; rejected because release packaging should be reproducible from committed files.

## Risks / Trade-offs

- [Risk] The native logo is restored but another token remains stale -> Mitigation: run `dart run tool/sync_splash_tokens.dart --check` after regeneration.
- [Risk] CI logs remain too generic for future maintainers -> Mitigation: include source/generated file hints and the exact sync command in script guidance.
- [Risk] GitHub workflow and local script behavior diverge -> Mitigation: keep workflow delegation to `tool/build_apk.ps1` and avoid duplicating project logic in YAML.
- [Risk] Build validation may be expensive -> Mitigation: use the focused token check as the minimum required validation, with full APK packaging as optional release-path validation.

## Migration Plan

1. Update the splash token source value for `logo_asset`.
2. Run the splash token generator once and commit any generated output changes.
3. Update packaging script diagnostics while keeping the preflight check mandatory.
4. Keep the GitHub release workflow delegated to `tool/build_apk.ps1`, adding only lightweight log/context improvements if needed.
5. Rollback is straightforward: revert the token/generated/script/workflow commit.

## Open Questions

- None. Keep current non-logo token source values unless the user explicitly requests a separate startup timing change.
