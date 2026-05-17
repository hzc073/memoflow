## Why

Local APK packaging and GitHub release packaging currently fail before `flutter build` because the splash token generated outputs are out of sync. The desired source of truth is to keep using the old native splash logo asset, `assets/splash/splash_logo_native.png`, instead of the newer `assets/images/streamline--wind-flow-1-remix.png` value.

## What Changes

- Restore the splash token source value so `logo_asset` uses `assets/splash/splash_logo_native.png`.
- Regenerate and verify splash token outputs so `tool/sync_splash_tokens.dart --check` passes locally and in GitHub Actions.
- Improve the APK/Windows PowerShell build scripts' stale splash token failure guidance so the error points maintainers to the source-of-truth token file and generated outputs.
- Adjust the GitHub APK workflow only as needed to keep the release log clear and aligned with the script-level preflight check.
- No API behavior, app data model, commercial/private hooks, or user-facing feature behavior changes are intended.

## Capabilities

### New Capabilities
- `splash-build-token-consistency`: Defines the packaging-time guarantee that splash token source values and generated outputs stay synchronized before release artifacts are built.

### Modified Capabilities
- None.

## Impact

- Affected files are expected to stay scoped to splash-token configuration/generated outputs and release tooling:
  - `memos_flutter_app/tool/splash_tokens.yaml`
  - `memos_flutter_app/lib/core/splash_tokens.g.dart`
  - `memos_flutter_app/android/app/src/main/res/values/splash.xml` if regeneration changes it
  - `memos_flutter_app/flutter_native_splash.yaml` if regeneration changes it
  - `memos_flutter_app/tool/build_apk.ps1`
  - `memos_flutter_app/tool/build_windows.ps1`
  - `.github/workflows/build_release_apk.yml`
- Active architecture phase is `evolve_modularity`; this change does not touch known coupling hotspots (`state -> features`, `application -> features`, `core -> higher layers`, or reused domain logic in widgets/screens).
- Validation should include the splash token check and, when practical, the focused APK packaging preflight or release script path.
