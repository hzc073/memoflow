## Requirements

### Requirement: Native splash logo token
The splash token source SHALL use `assets/splash/splash_logo_native.png` as the `logo_asset` value for the generated startup splash tokens.

#### Scenario: Generated Dart token uses native logo
- **WHEN** `dart run tool/sync_splash_tokens.dart` is run from `memos_flutter_app`
- **THEN** `lib/core/splash_tokens.g.dart` SHALL define `SplashTokens.logoAsset` as `assets/splash/splash_logo_native.png`

#### Scenario: Token check accepts committed outputs
- **WHEN** `dart run tool/sync_splash_tokens.dart --check` is run from `memos_flutter_app` on a clean checkout
- **THEN** the command SHALL exit successfully without reporting stale splash token outputs

### Requirement: Packaging scripts enforce splash token consistency
The local packaging scripts SHALL verify that committed splash token outputs match `tool/splash_tokens.yaml` before invoking release packaging builds.

#### Scenario: APK packaging rejects stale splash outputs
- **WHEN** `tool/build_apk.ps1` is run and generated splash outputs differ from `tool/splash_tokens.yaml`
- **THEN** the script SHALL stop before building APK or AAB artifacts

#### Scenario: Windows packaging rejects stale splash outputs
- **WHEN** `tool/build_windows.ps1` is run and generated splash outputs differ from `tool/splash_tokens.yaml`
- **THEN** the script SHALL stop before building Windows artifacts

### Requirement: Packaging failure guidance is actionable
Splash token preflight failures SHALL tell maintainers how to resynchronize the token outputs and where the source token file lives.

#### Scenario: Stale token failure includes sync command
- **WHEN** a packaging script detects stale splash token outputs
- **THEN** the failure message SHALL include `dart run tool/sync_splash_tokens.dart`

#### Scenario: Stale token failure names source of truth
- **WHEN** a packaging script detects stale splash token outputs
- **THEN** the failure guidance SHALL mention `tool/splash_tokens.yaml` as the source-of-truth token file

### Requirement: GitHub APK workflow uses project packaging guard
The GitHub APK release workflow SHALL package APK artifacts through the project APK build script so CI uses the same splash token consistency guard as local release packaging.

#### Scenario: GitHub APK release delegates to build script
- **WHEN** `.github/workflows/build_release_apk.yml` builds APK packages
- **THEN** the workflow SHALL call `tool/build_apk.ps1` from `memos_flutter_app`
