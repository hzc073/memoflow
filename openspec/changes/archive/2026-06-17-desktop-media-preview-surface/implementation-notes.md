## 第一阶段决策

- Platform gate: macOS 启用独立 desktop media preview window；Windows 和 Linux 暂时走 main-window immersive fallback，直到子窗口媒体能力完成真实平台验证。
- Window instance policy: 第一阶段允许每次打开创建一个独立 media window；后续如需要可收敛为单 active window + focus/replace 策略。
- Editable preview policy: 带 `onReplace` 的可编辑/可替换预览第一阶段走 main-window immersive fallback，避免跨子窗口直接传递 Dart callback 或把 pending attachment/memo mutation owner 移入媒体窗口。
- Scope guard: 本 change 不触碰 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、数据库 schema、sync protocol、商业/private overlay 逻辑。

## 入口清单

- `ImagePreviewLauncher.open` 已覆盖 memo reader/detail、memo card、memo media grid、memo image grid、memo editor、inline compose、note input sheet、markdown inline image 和 engagement surface 等图片路径。
- 仍直接 push `AttachmentGalleryScreen` 的入口包括 `MemoMediaGrid` mixed gallery、`AttachmentGalleryScreen` 内部切换、collection reader、desktop quick input pending attachment 等。
- 仍直接 push `AttachmentVideoScreen` 的入口包括 resources、share clip、collection reader、memo media grid、attachment gallery 内部视频、note input sheet 等。
- `explore_screen.dart` 目前有单独的 `_openImagePreview(String url)` 临时图片预览路径，需要迁移或记录无法迁移原因。
- 第一阶段不会修改 API adapter、同步协议、数据库 schema 或 private/commercial overlay；可编辑/替换 preview 暂时保留在 main-window immersive fallback，由原 owner 继续持有 mutation callback。

## 实现结果

- 新增 `features/media_preview`：包含 `DesktopMediaPreviewRequest` / `DesktopMediaPreviewResult` codec、macOS media window opener、media window app root 和集中 `MediaPreviewLauncher`。
- `ImagePreviewLauncher.open` 改为代理到集中 launcher；桌面端无 `onReplace` 时优先尝试独立 media window，失败或不支持时进入无普通 `AppBar` 的沉浸式 fallback。
- `ImagePreviewGalleryBody`、`AttachmentGalleryScreen`、`AttachmentVideoScreen` 增加桌面沉浸式 chrome：无普通 `AppBar` / App-level Back，保留页码、下载、编辑/替换、视频控制、关闭按钮和 `Esc`。
- macOS 顶部媒体状态控件使用 `DesktopWindowChromeSafeArea`，没有在媒体 viewer 内硬编码 `kMacosTrafficLightReservedWidth`。
- 已迁移 `MemoMediaGrid`、`MemoVideoGrid`、resources、share clip、collection reader、desktop quick input、note input、explore 临时图片预览等入口到集中 launcher 或其 image launcher 间接入口。
- 带 `onReplace` 的图片/附件编辑入口第一阶段保留在 main-window immersive fallback；独立窗口只承载可序列化、无 Dart callback 的查看请求。

## 验证记录

- `openspec validate desktop-media-preview-surface --strict` 通过。
- `flutter analyze` 通过。
- Focused tests 通过：
  - `test/features/media_preview/desktop_media_preview_request_test.dart`
  - `test/features/image_preview/image_preview_gallery_screen_test.dart`
  - `test/features/memos/attachment_gallery_screen_test.dart`
  - `test/features/memos/attachment_video_screen_test.dart`
  - `test/architecture/desktop_media_preview_surface_guardrail_test.dart`
- API compatibility tests 通过：`flutter test test/data/api --reporter expanded`。
- `flutter test` 已运行；全量套件仅失败既有 settings/db 测试 `desktop db changed event invalidates local database listeners`，原因是 `AppDatabase._scheduleMemoSearchMaintenance` 留下 80ms pending timer。该失败路径不在本 change touched files 内。
- API adapter 检查：`memos_flutter_app/lib/data/api` 和 `memos_flutter_app/test/data/api` 无 diff。
- commercial/private scan：本 change touched files 未命中 subscription、billing、entitlement、StoreKit、paywall、private overlay 等关键词。

## 未完成

- 尚未做 macOS 真机手动 smoke：单张图片、多图、视频和 pending attachment 的系统关闭按钮 / `Esc` 关闭仍需在实际桌面窗口里确认。
