## ADDED Requirements

### Requirement: iOS native launch surfaces use splash tokens
iOS public shell native launch surfaces SHALL be generated from or verified against `tool/splash_tokens.yaml` so the visible app startup before Flutter first frame matches the committed splash tokens.

#### Scenario: iOS LaunchScreen uses token background and logo
- **WHEN** `dart run tool/sync_splash_tokens.dart` is run from `memos_flutter_app`
- **THEN** `ios/Runner/Base.lproj/LaunchScreen.storyboard` SHALL use a background color matching `splash.background_color`
- **AND** the launch screen SHALL reference a non-empty logo or launch image resource derived from `splash.ios_logo_asset`

#### Scenario: iOS Flutter handoff view avoids white fallback
- **WHEN** `dart run tool/sync_splash_tokens.dart` is run from `memos_flutter_app`
- **THEN** `ios/Runner/Base.lproj/Main.storyboard` SHALL use a root `FlutterViewController` view background matching `splash.background_color`

### Requirement: iOS stale splash placeholders are rejected
The splash token check SHALL fail when iOS native launch outputs retain Flutter template placeholders, white fallback backgrounds, transparent one-pixel launch images, or values that do not match `tool/splash_tokens.yaml`.

#### Scenario: Check rejects white iOS launch screen background
- **WHEN** `dart run tool/sync_splash_tokens.dart --check` is run from `memos_flutter_app`
- **AND** `ios/Runner/Base.lproj/LaunchScreen.storyboard` still contains a white launch background instead of `splash.background_color`
- **THEN** the command SHALL fail before reporting splash token outputs as current

#### Scenario: Check rejects transparent one-pixel LaunchImage assets
- **WHEN** `dart run tool/sync_splash_tokens.dart --check` is run from `memos_flutter_app`
- **AND** `ios/Runner/Assets.xcassets/LaunchImage.imageset` contains transparent 1x1 placeholder PNG assets
- **THEN** the command SHALL fail before reporting splash token outputs as current

#### Scenario: Check rejects white iOS handoff background
- **WHEN** `dart run tool/sync_splash_tokens.dart --check` is run from `memos_flutter_app`
- **AND** `ios/Runner/Base.lproj/Main.storyboard` still contains a white `FlutterViewController` root view background
- **THEN** the command SHALL fail before reporting splash token outputs as current

## MODIFIED Requirements

### Requirement: Packaging scripts enforce splash token consistency
The local packaging scripts SHALL verify that every committed Flutter, Android, and iOS splash token output matches `tool/splash_tokens.yaml` before invoking release packaging builds.

#### Scenario: APK packaging rejects stale splash outputs
- **WHEN** `tool/build_apk.ps1` is run and generated splash outputs differ from `tool/splash_tokens.yaml`
- **THEN** the script SHALL stop before building APK or AAB artifacts

#### Scenario: APK packaging checks splash outputs before Flutter build
- **WHEN** `tool/build_apk.ps1` is run
- **THEN** the script SHALL run `dart run tool/sync_splash_tokens.dart --check` before the first `flutter build` command

#### Scenario: Windows packaging rejects stale splash outputs
- **WHEN** `tool/build_windows.ps1` is run and generated splash outputs differ from `tool/splash_tokens.yaml`
- **THEN** the script SHALL stop before building Windows artifacts

#### Scenario: Windows packaging checks splash outputs before Flutter build
- **WHEN** `tool/build_windows.ps1` is run
- **THEN** the script SHALL run `dart run tool/sync_splash_tokens.dart --check` before the first `flutter build` command

### Requirement: Packaging failure guidance is actionable
Splash token preflight failures SHALL tell maintainers how to resynchronize the token outputs, where the source token file lives, and which stale output path caused the failure when that path can be determined.

#### Scenario: Stale token failure includes sync command
- **WHEN** a packaging script detects stale splash token outputs
- **THEN** the failure message SHALL include `dart run tool/sync_splash_tokens.dart`

#### Scenario: Stale token failure names source of truth
- **WHEN** a packaging script detects stale splash token outputs
- **THEN** the failure guidance SHALL mention `tool/splash_tokens.yaml` as the source-of-truth token file

#### Scenario: Stale iOS launch output failure names affected path
- **WHEN** the splash token check detects a stale iOS launch screen, handoff storyboard, or `LaunchImage.imageset` output
- **THEN** the failure guidance SHALL name the affected `ios/Runner/...` path
