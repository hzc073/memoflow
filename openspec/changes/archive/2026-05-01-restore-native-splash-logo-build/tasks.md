## 1. Splash Token Source

- [x] 1.1 Update `memos_flutter_app/tool/splash_tokens.yaml` so `logo_asset` is `assets/splash/splash_logo_native.png` while preserving current non-logo token source values.
- [x] 1.2 Run `dart run tool/sync_splash_tokens.dart` from `memos_flutter_app` to regenerate splash outputs.
- [x] 1.3 Review generated output changes and confirm `lib/core/splash_tokens.g.dart` uses `assets/splash/splash_logo_native.png` for `SplashTokens.logoAsset`.

## 2. Packaging Diagnostics

- [x] 2.1 Improve `memos_flutter_app/tool/build_apk.ps1` stale splash token guidance so it names `tool/splash_tokens.yaml` and the sync command.
- [x] 2.2 Improve `memos_flutter_app/tool/build_windows.ps1` stale splash token guidance with the same source-of-truth and sync-command wording.
- [x] 2.3 Review `.github/workflows/build_release_apk.yml` and keep the APK release path delegated to `tool/build_apk.ps1`, adding lightweight log context only if useful.

## 3. Verification

- [x] 3.1 Run `dart run tool/sync_splash_tokens.dart --check` from `memos_flutter_app`.
- [x] 3.2 Run a focused PowerShell syntax/preflight validation for `tool/build_apk.ps1` and `tool/build_windows.ps1` without producing release artifacts when practical.
- [x] 3.3 Confirm `git status --short` includes only the intended splash-token, generated-output, packaging-script, workflow, and OpenSpec files.
