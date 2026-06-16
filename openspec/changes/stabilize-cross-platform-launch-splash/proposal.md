## Why

iOS 原生启动页仍使用白色背景和 1x1 占位 `LaunchImage`，与 `tool/splash_tokens.yaml` 中的启动页背景色、logo token 不一致，因此在 Flutter 首帧之前会出现可见白屏。Android 已经接入原生 splash 与 token 校验，这次需要把同一套机制扩展为多平台稳定方案，避免后续发布包再次产生平台差异。

## What Changes

- 扩展 splash token 同步能力，让 `tool/splash_tokens.yaml` 成为 Flutter 启动屏、Android 原生 splash、iOS 原生 `LaunchScreen.storyboard`、iOS Flutter handoff 背景与相关启动图资源的共同来源。
- 为 iOS 启动页产物增加生成或严格校验，覆盖 `ios/Runner/Base.lproj/LaunchScreen.storyboard`、`ios/Runner/Base.lproj/Main.storyboard` 和 `ios/Runner/Assets.xcassets/LaunchImage.imageset`，确保不再提交白色背景或透明占位图。
- 扩展 `dart run tool/sync_splash_tokens.dart --check`，在 iOS 原生启动页与 token 不一致时失败，并给出可执行的同步修复提示。
- 将本地打包和发布前检查提升为跨平台 splash 一致性检查，保持 Android/Windows 既有行为，同时补齐 iOS 公共壳启动页检查。
- 明确本变更不处理启动后数据同步、列表首屏重建、debug mode 性能抖动或 `file_picker` crash；这些属于后续独立启动性能/稳定性问题。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `splash-build-token-consistency`: 将既有 splash token 一致性要求从 Android/Windows 打包前检查扩展到 iOS 原生启动页和 Flutter handoff 背景，要求 iOS 不再保留白色/透明占位启动页产物。

## Impact

- Affected code and assets:
  - `memos_flutter_app/tool/splash_tokens.yaml`
  - `memos_flutter_app/tool/sync_splash_tokens.dart`
  - `memos_flutter_app/lib/core/splash_tokens.g.dart`
  - `memos_flutter_app/flutter_native_splash.yaml`
  - `memos_flutter_app/ios/Runner/Base.lproj/LaunchScreen.storyboard`
  - `memos_flutter_app/ios/Runner/Base.lproj/Main.storyboard`
  - `memos_flutter_app/ios/Runner/Assets.xcassets/LaunchImage.imageset/*`
  - packaging/check scripts that invoke splash token preflight checks
- No API route, request/response model, database schema, subscription, StoreKit, entitlement, paywall, or private overlay behavior is introduced.
- Architecture phase remains `evolve_modularity`; this change is tooling/native-shell focused and does not touch current `state -> features`, `application -> features`, `core -> higher-layer`, or screen-level shared domain logic hotspots. The modularity checklist items most relevant to this change are item 8 guardrails and item 10 touched areas remaining equal or better structured.
