## 1. Share payload 模式

- [x] 1.1 在 `SharePayload` 中新增向后兼容的 handling mode，例如 `standardShare` 和 `quickRecord`，并让缺省/旧 payload 解析为 `standardShare`。
- [x] 1.2 更新 share payload JSON/Map 编解码测试，覆盖旧 payload、`quickRecord` payload、未知 mode fallback。
- [x] 1.3 明确 `quickRecord` mode 只影响 Flutter 分流，不改变 `buildShareTextDraft` 的普通文本格式化行为。

## 2. Android 入口接收

- [x] 2.1 在 `AndroidManifest.xml` 为 Android 选中文本快速记录注册 `ACTION_PROCESS_TEXT` + `text/plain` 的 activity intent-filter。
- [x] 2.2 扩展 `MainActivity.handleShareIntent` 或提取 native helper，解析 `Intent.EXTRA_PROCESS_TEXT` 并标记为 `quickRecord`。
- [x] 2.3 在 `EXTRA_TEXT` 不存在时读取纯文本 `ClipData`，将拖拽式文本标记为 `quickRecord`。
- [x] 2.4 保持普通 `ACTION_SEND` / `ACTION_SEND_MULTIPLE` 的 `EXTRA_TEXT` 分享为 `standardShare`，避免普通 URL 分享回归。
- [x] 2.5 复用现有 URI 缓存路径接收图片、视频等媒体 URI，并确保单个 URI 读取失败不会导致崩溃。

## 3. Flutter 分流行为

- [x] 3.1 在 share startup flow 中让 `quickRecord` 文本直接打开 `NoteInputSheet`，即使文本包含 HTTP(S) URL 也不调用 QuickClip/capture 路径。
- [x] 3.2 保持 `standardShare` URL 继续走现有 QuickClip/剪藏流程。
- [x] 3.3 确保 `quickRecord` 媒体 payload 打开 `NoteInputSheet` 并预填附件，仍需用户确认发送。
- [x] 3.4 复用现有 `thirdPartyShareEnabled`、工作区可用性、share flow release 和 clipboard retry 逻辑。

## 4. 模块化与边界保护

- [x] 4.1 将 quickRecord 分流判断限制在 share payload / share startup seam，避免 Android intent 细节进入 memo UI、state provider 或 core utility。
- [x] 4.2 若触碰 `startup_coordinator_share.dart`，补充回归测试证明没有改变普通分享 URL 剪藏路径。
- [x] 4.3 运行或更新架构 guardrail，确认没有新增 `state -> features`、`core -> state|application|features` 依赖，也没有扩大 allowlist。
- [x] 4.4 确认本 change 不修改 `memos_flutter_app/lib/data/api/**` 或 `memos_flutter_app/test/data/api/**`。
- [x] 4.5 确认本 change 不新增 subscription、billing、entitlement、paywall、StoreKit 或其他商业逻辑。

## 5. 测试与验证

- [x] 5.1 增加 `SharePayload`/share handler 单元测试，覆盖 `quickRecord` mode 解析和默认兼容。
- [x] 5.2 增加 StartupCoordinator 测试：`quickRecord` URL 打开 composer，不显示 QuickClip sheet。
- [x] 5.3 增加 StartupCoordinator 测试：`standardShare` URL 保持现有 QuickClip/剪藏行为。
- [x] 5.4 增加 StartupCoordinator 测试：`thirdPartyShareEnabled=false` 时 quickRecord 不打开 composer。
- [x] 5.5 增加或更新媒体附件路径测试，覆盖 quickRecord 图片/视频附件进入 composer。
- [ ] 5.6 在 Android 设备或模拟器上用 `adb shell am start` 验证 `ACTION_PROCESS_TEXT`、纯文本 `ClipData`、单媒体 URI、多媒体 URI。
- [ ] 5.7 在至少一台 Android 真机上验证目标厂商侧边栏/选中文本/拖拽入口的实际行为，并记录不支持或需要后续 activity alias 的情况。
- [x] 5.8 在 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 5.9 在 `memos_flutter_app` 运行 `flutter test`，并重点确认 share/startup 相关测试通过。
