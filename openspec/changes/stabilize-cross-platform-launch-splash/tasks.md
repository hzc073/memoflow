## 1. Baseline Confirmation

- [x] 1.1 确认 `tool/splash_tokens.yaml`、`LaunchScreen.storyboard`、`Main.storyboard`、`LaunchImage.imageset`、`build_apk.ps1` 和 `build_windows.ps1` 的当前差异，确保实现只覆盖 splash 启动页一致性问题。
- [x] 1.2 确认本变更不触碰 API 目录、商业能力、StoreKit、订阅、付费状态、private overlay hooks 或公共模型中的付费字段。

## 2. Token Sync Implementation

- [x] 2.1 扩展 `tool/sync_splash_tokens.dart`，让 iOS `LaunchScreen.storyboard` 背景色和 logo/launch image 引用由 `tool/splash_tokens.yaml` 生成或严格校验。
- [x] 2.2 扩展 `tool/sync_splash_tokens.dart`，让 iOS `Main.storyboard` 的 `FlutterViewController` 根 view 背景与 `splash.background_color` 保持一致。
- [x] 2.3 扩展 `tool/sync_splash_tokens.dart --check`，在 iOS 白色背景、1x1 透明 `LaunchImage` 占位图或 token drift 出现时失败，并输出受影响的 `ios/Runner/...` 路径。
- [x] 2.4 保持既有 Dart token、Android splash XML 和 `flutter_native_splash.yaml` 输出兼容，除非 token source 明确要求变化。

## 3. Generated Platform Outputs

- [x] 3.1 运行 `dart run tool/sync_splash_tokens.dart`，提交由 token 生成的 iOS storyboard、asset catalog 和相关 splash 输出。
- [x] 3.2 检查 iOS launch logo 视觉尺寸和透明边距，优先复用 `assets/splash/splash_logo_native.png`，避免新增不必要的 token schema。
- [x] 3.3 确认 Android 原生 splash 与 Flutter `StartupScreen` 仍消费同一套 token，且没有引入平台分叉配置。

## 4. Packaging And Guardrails

- [x] 4.1 补齐或修正 `tool/build_apk.ps1`，确保它在第一个 `flutter build` 前运行 `dart run tool/sync_splash_tokens.dart --check`。
- [x] 4.2 保持 `tool/build_windows.ps1` 的 splash token preflight，并让失败提示与新增 iOS stale path 输出一致。
- [x] 4.3 添加 focused test/guardrail，覆盖 iOS launch screen 非白色背景、`Main.storyboard` handoff 背景、非 1x1 透明 `LaunchImage`、以及 `--check` stale output 失败路径。
- [x] 4.4 确认 iOS public shell guardrail 仍阻止商业 runtime、release secrets、StoreKit 或 private hook 泄漏。

## 5. Verification

- [x] 5.1 在 `memos_flutter_app` 运行 `dart run tool/sync_splash_tokens.dart --check`。
- [x] 5.2 在 `memos_flutter_app` 运行新增或受影响的 focused tests，包括 iOS splash/public shell guardrail。
- [x] 5.3 在 `memos_flutter_app` 运行 `flutter analyze` 和 `flutter test`，若受本地环境限制无法完成则记录具体原因。
- [x] 5.4 在 iPhone/iPad 和 Android 设备或模拟器执行冷启动 smoke test，确认 Flutter 首帧前不再出现白屏；若设备不可用则记录未覆盖风险。（2026-06-16：`flutter devices` 仅发现一台物理 iPhone、macOS 和 Chrome；`flutter emulators` 无可用 emulator source，当前 CLI 无法视觉确认物理 iPhone 的冷启动过渡，Android/iPad smoke test 未覆盖，需人工复核。）
