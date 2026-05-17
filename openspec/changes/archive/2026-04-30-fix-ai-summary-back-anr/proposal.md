## Why

在 AI Summary 界面通过 Android back 或标题栏返回时，当前 overlay navigation host 与 page-level `PopScope` 会互相触发 `Navigator.maybePop()`，形成 CPU-bound Dart microtask loop，最终导致 input dispatching ANR。这个问题已经在 ANR trace 与 live Dart stack 中确认，且同类 overlay route 也可能复现。

## What Changes

- 修复 bottom navigation shell 推出的 standalone overlay routes 的 back-to-primary 行为，确保 back action 只完成一次 route dismiss 或一次 tab switch，不再递归调用 `maybePop()`。
- 为 AI Summary 返回路径增加回归验证，覆盖 `HomeScreenPresentation.standalone` + `HomeEmbeddedNavigationHost` 的组合。
- 评估并约束同类页面（例如 Explore、Resources、Daily Review、Notifications）共享的 overlay host 返回语义，避免只修 AI Summary 而留下同样的导航陷阱。
- 保持 AI Summary settings、prompt editor、WebDAV settings sync 行为不变；本 change 不修改 AI API、sync 协议或商业/private hooks。
- Architecture phase remains `evolve_modularity`; touched checklist items: `6.` feature-to-feature collaboration should prefer boundary/registry/provider seams, `8.` guardrail tests protect high-risk dependency directions, and `10.` touched coupled areas leave equal or better structure.

## Capabilities

### New Capabilities
- `home-navigation-back-safety`: Defines safe back navigation behavior for bottom-nav embedded pages and standalone overlay routes that use `HomeEmbeddedNavigationHost`.

### Modified Capabilities
- `modularity-governance`: Documents that navigation fixes in coupled feature/home areas must preserve the host seam and add guardrails rather than introducing direct feature-to-feature shortcuts.

## Impact

- Affected code areas: `memos_flutter_app/lib/features/home/home_bottom_nav_shell.dart`, `memos_flutter_app/lib/features/home/home_navigation_host.dart`, and back handling in `memos_flutter_app/lib/features/review/ai_summary_screen.dart` or peer screens if needed.
- Affected tests: focused widget tests under `memos_flutter_app/test/features/home` and/or `memos_flutter_app/test/features/review` for overlay route back behavior.
- No expected API, database, WebDAV protocol, localization key, or dependency changes.
