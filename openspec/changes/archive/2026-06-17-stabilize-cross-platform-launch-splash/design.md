## Context

当前启动页链路有三层：原生启动页、Flutter 引擎接管前的 handoff 背景、Flutter 内部 `StartupScreen`。Android 已经通过 `installSplashScreen()`、`Theme.SplashScreen` 和 `tool/splash_tokens.yaml` 生成的资源接近同源；Flutter 内部也使用 `lib/core/splash_tokens.g.dart`。iOS 仍停留在 Flutter 默认模板状态：`LaunchScreen.storyboard` 背景为白色，`LaunchImage` 是 1x1 gray+alpha 占位图，`Main.storyboard` 的 `FlutterViewController` 根 view 也是白色背景。

这说明问题不是 Flutter 自定义启动页不支持 iOS，而是 iOS 原生启动窗口没有被纳入现有 token 同步和打包前校验。只改 Flutter `StartupScreen` 无法覆盖首帧之前的系统 launch screen，因此需要把 iOS 原生产物纳入同一个 source of truth。

Architecture phase is `evolve_modularity`。本变更触及 tooling、native shell 和 asset 产物，不新增 `state -> features`、`application -> features` 或 `core -> higher-layer` 依赖，也不移动共享业务逻辑到 screen/widget 文件。前后依赖方向保持为：build/tooling 读取 token 并生成平台产物，Flutter runtime 只消费已生成的 `SplashTokens` 和 assets。计划新增或收紧 `--check`/测试 guardrail，对应 checklist item 8 和 item 10。

## Goals / Non-Goals

**Goals:**

- 让 `tool/splash_tokens.yaml` 成为 Flutter、Android、iOS 启动页视觉 token 的唯一来源。
- 让 `dart run tool/sync_splash_tokens.dart` 能同步 iOS 原生启动页关键产物，或至少在 `--check` 下严格验证这些产物与 token 一致。
- 消除 iOS 首帧前可见白屏：`LaunchScreen.storyboard`、`Main.storyboard` handoff 背景和 launch image/logo 资源不得继续使用白色/透明占位默认值。
- 让本地 packaging preflight 和自动化测试能阻止陈旧 iOS splash 产物进入发布包。
- 保持公共仓库边界，不引入 StoreKit、订阅、付费能力或 private overlay hooks。

**Non-Goals:**

- 不优化 Flutter 首帧之后的启动性能、自动同步、memo list rebuild 或动画策略。
- 不处理 `file_picker` duplicate class warning 或 iOS native crash。
- 不新增 API、数据库 schema、远端兼容逻辑或账号/session 模型字段。
- 不引入新的图片生成服务或运行时依赖；启动页资源继续使用仓库内已声明 assets。

## Decisions

1. **保留 `tool/splash_tokens.yaml` 为唯一 source of truth。**
   - Rationale: 现有 Dart token、Android XML、`flutter_native_splash.yaml` 已由该文件生成，继续扩展同一脚本比新增第二套 iOS 配置更容易检查和回滚。
   - Alternative considered: 只手工修改 Xcode storyboard。该方式可以立即消除白屏，但没有防回归机制，后续重新运行 `flutter create`、插件生成或人工改动时容易再次漂移。

2. **优先生成/校验 storyboard 与 asset catalog，而不是只依赖 `flutter_native_splash.yaml`。**
   - Rationale: 当前 `flutter_native_splash.yaml` 已声明 `ios: true` 和 `image_ios`，但 iOS committed outputs 仍是白屏和占位图，说明“配置存在”不足以保证发布产物正确。最终方案必须检查实际提交的 `ios/Runner/...` 文件。
   - Alternative considered: 在构建时要求维护者手动运行 `flutter pub run flutter_native_splash:create`。这依赖外部命令副作用，仍缺少 committed-output 校验，且难以在失败消息中准确指出 stale path。

3. **iOS launch screen 使用背景色 + 居中 logo asset 的稳定布局。**
   - Rationale: storyboard 的背景色应匹配 `splash.background_color`，logo 应来自 `splash.ios_logo_asset` 对应的非空资源；这种形式比全屏背景图更适配不同 iPhone/iPad 尺寸和 safe area。
   - Alternative considered: 使用一张全屏启动图覆盖所有尺寸。该方案会引入裁切、倍率和深浅色适配问题，不适合作为根本方案。

4. **`Main.storyboard` handoff 背景也纳入校验。**
   - Rationale: iOS 从 launch screen 切到 `FlutterViewController` 时，如果根 view 仍为白色，即使 `LaunchScreen.storyboard` 已修好，Flutter 首帧前也可能短暂露白。
   - Alternative considered: 只修 `LaunchScreen.storyboard`。这不能覆盖 launch screen 到 Flutter surface 之间的间隙。

5. **把防回归放在脚本 `--check` 和测试中，而不是 UI runtime。**
   - Rationale: 这是 native shell/build artifact 一致性问题，最佳拦截点是生成器、packaging preflight 和 architecture/tooling tests。Flutter UI runtime 无法控制系统 launch screen，也不应承担 native asset 校验。
   - Alternative considered: 在 `StartupScreen` 中延长停留或改动画。该方案只能覆盖 Flutter 首帧之后，无法修复用户看到的首帧前白屏。

## Risks / Trade-offs

- [Risk] 直接生成 storyboard XML 可能与 Xcode 后续保存格式产生差异。→ Mitigation: 生成稳定、最小化的 storyboard 结构，并用测试检查关键语义而不是依赖无关 XML 排版。
- [Risk] logo 资源尺寸或透明边距不合适时，iOS launch screen 视觉可能与 Android 不完全一致。→ Mitigation: 使用现有 `splash_logo_native.png` 作为单一 logo source，并在任务中要求 iPhone/iPad smoke test。
- [Risk] `build_apk.ps1` 目前未搜索到 `sync_splash_tokens.dart --check` 调用，现有 spec 与实现可能已有偏差。→ Mitigation: implementation phase 先补齐/验证 APK preflight，再扩展为跨平台输出检查。
- [Risk] 过度依赖 `flutter_native_splash.yaml` 会再次出现“配置正确但 committed outputs 陈旧”。→ Mitigation: `--check` 直接读取并验证 `ios/Runner/Base.lproj/*.storyboard` 与 `LaunchImage.imageset`。
- [Risk] debug mode 首帧之后仍可能卡顿，让用户误以为启动页问题未修复。→ Mitigation: 本变更只保证白屏/handoff；启动后 10 秒卡顿作为独立性能变更继续分析。

## Known Follow-ups

- [Regression noted] `MainHomePage._resolveStartupShowSlogan()` 当前会在偏好加载前用系统 locale 锁定 `StartupScreen.showSlogan`，后续即使 `prefs.language` 已加载也不会覆盖该初始判断。若系统语言为 English 但 App 偏好语言为非 English，启动 slogan 可能被隐藏；若系统语言为非 English 但 App 偏好为 English，启动页可能继续显示 slogan 并触发最小时长。该问题不影响本 change 的原生 splash 白屏修复，但属于 Flutter 内部启动页语言/停留策略回归，应在后续启动体验 change 中决定是否允许已加载的 App 语言偏好覆盖首帧前 fallback。

## Migration Plan

1. 扩展 `tool/sync_splash_tokens.dart` 的输出集合和 `--check` 差异报告，加入 iOS storyboard、asset catalog 与 stale placeholder 检查。
2. 重新生成并提交 iOS 启动页产物，使背景色、logo 引用和 handoff 背景与 token 一致。
3. 补齐 `build_apk.ps1` 的 splash preflight，并保持 `build_windows.ps1` 与 GitHub APK workflow 通过同一脚本路径执行检查。
4. 添加 focused tests/guardrails，覆盖 iOS 白色背景、1x1 透明占位图、token drift 和失败提示。
5. 在 iPhone/iPad 与 Android 上做 smoke test：从冷启动到 Flutter 首帧前不得出现白屏；Flutter 首帧后的性能问题另行记录。

Rollback strategy: 如果 storyboard 生成造成 iOS 构建异常，可以回滚生成的 iOS storyboard/assets 与脚本扩展；Android/Windows 既有 token 输出不需要回滚。

## Open Questions

- iOS launch logo 的目标显示尺寸是否沿用现有 `LaunchScreen.storyboard` resource metadata 的 168x185，还是由 token 文件新增显式尺寸字段？默认实现应先避免新增 token schema，除非实际设备 smoke test 证明需要尺寸配置。
- 是否需要单独新增 iOS release packaging script。当前计划先通过通用 `sync_splash_tokens.dart --check`、测试和现有发布路径防回归，不把 iOS 发布自动化纳入本次范围。
