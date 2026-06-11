## Context

当前 Android shell 已在 `AndroidManifest.xml` 注册 `ACTION_SEND` 与 `ACTION_SEND_MULTIPLE`，`MainActivity.handleShareIntent` 会把 `EXTRA_TEXT` 或 `EXTRA_STREAM` 转成 `SharePayload`，Flutter 启动协调器再打开 QuickClip 或 `NoteInputSheet`。但现状有三个缺口：

- `ACTION_PROCESS_TEXT` 只在 `<queries>` 中声明，MemoFlow 本身不会作为“处理选中文本”的目标出现。
- 拖拽或厂商中转站可能把文本放在 `ClipData`，而当前 native 只把 `ClipData` 当 URI 来源读取。
- Flutter 分享流会根据 URL 内容进入 QuickClip；新增快速记录入口需要把 URL 保留为普通文本，同时普通第三方分享不能回归。

项目当前处于 `evolve_modularity` 阶段。若实现触碰 `memos_flutter_app/lib/application/startup/startup_coordinator_share.dart`，必须避免扩大既有 `application -> features` 耦合，并通过窄 payload seam 与测试守住边界。

## Goals / Non-Goals

**Goals:**

- 为 Android 侧边栏、选中文本、拖拽类来源提供快速记录入口。
- 快速记录入口接收纯文本、图片、视频等媒体文件，并打开输入框让用户确认发送。
- 快速记录入口中的 URL 按普通文本保存，不进入 QuickClip/剪藏。
- 普通第三方分享入口保持现有 URL 剪藏能力。
- 复用现有 `thirdPartyShareEnabled`、工作区可用性、输入框附件 staging 与本地保存/同步流程。

**Non-Goals:**

- 不做自动保存或后台静默创建 memo。
- 不改变普通第三方分享、剪藏、QuickClip recovery 的既有需求。
- 不覆盖 iOS、Windows、macOS 或桌面快捷输入。
- 不引入厂商私有 SDK；厂商侧边栏差异通过标准 Android intent 与真机验证覆盖。
- 不修改 Memos server API 或 API 兼容性测试。

## Decisions

### 1. 用 payload 模式区分快速记录与普通分享

在 Dart `SharePayload` 中增加一个向后兼容的处理模式，例如 `SharePayloadHandlingMode.standardShare` 与 `SharePayloadHandlingMode.quickRecord`。native 传入缺省模式时按 `standardShare` 解析，确保旧分享入口继续按 URL 剪藏处理。

`quickRecord` 模式只影响 Flutter 侧分流：即使文本包含 HTTP(S) URL，也直接打开 `NoteInputSheet`，不调用 QuickClip preview/capture 路径。

备选方案是全局关闭 URL 剪藏或按 URL 内容推断行为，但这会回归普通分享体验，因此不采用。

### 2. native 入口归一化负责标记 quickRecord

`MainActivity` 应把以下来源归一化为快速记录 payload：

- `ACTION_PROCESS_TEXT` 的 `EXTRA_PROCESS_TEXT`。
- 纯文本 `ClipData`，尤其是没有 `EXTRA_TEXT` 的拖拽式输入。

普通 `ACTION_SEND` / `ACTION_SEND_MULTIPLE` 的既有 `EXTRA_TEXT` 分享保持 `standardShare`，避免浏览器、其他 App 的普通分享 URL 被误改成纯文本。

媒体 URI 仍可复用当前缓存到临时文件再传 `paths` 的方式。虽然现有 Dart 枚举名是 `images`，`NoteInputSheet` 实际会按文件扩展推断 image/video/audio 等 MIME；实现时可以先复用该路径，必要时再用更准确的命名做小步清理。

### 3. Flutter 启动协调保持现有资格判断

快速记录 payload 仍进入现有 `_handlePendingShare` 资格判断：

- `thirdPartyShareEnabled` 关闭时不打开输入框。
- 没有远程账号或本地工作区时不消费为可提交记录。
- share flow active 状态和 clipboard retry 的释放逻辑继续复用现有路径。

仅在打开 UI 的分支上新增“quickRecord 跳过 QuickClip”的判断。

### 4. 模块化约束与 guardrail

实现应把模式判断保持在 share payload / share flow seam 内，不把 Android intent 细节泄露到 memo UI、state provider 或 core utility。若修改 `startup_coordinator_share.dart`，应新增或扩展测试证明：

- `quickRecord` URL 打开 composer 而不是 QuickClip。
- `standardShare` URL 仍打开 QuickClip。
- 没有新增 `state -> features`、`application -> features` 或 `core -> higher-layer` 依赖例外。

## Risks / Trade-offs

- [Risk] 不同厂商侧边栏发送的 intent 不一致。→ [Mitigation] 先覆盖标准 `ACTION_PROCESS_TEXT`、`ACTION_SEND`、`ACTION_SEND_MULTIPLE`、`ClipData`；实现阶段用 Android 真机和 `adb` 命令验证 raw intent。
- [Risk] `ACTION_SEND` 的 URL 可能来自厂商侧边栏但无法与普通分享区分。→ [Mitigation] 保持普通 `EXTRA_TEXT` 分享为 `standardShare`，优先保证不回归；若真机确认某厂商只能发 `ACTION_SEND EXTRA_TEXT`，再单独评估 activity alias 或厂商特定识别。
- [Risk] 复用 `images` payload 名称接收视频会造成语义不清。→ [Mitigation] 第一版可复用现有附件 path 以降低风险；如实现需要改名，应保持 `images` 解析兼容并补 codec 测试。
- [Risk] 修改 startup share 分流可能影响 clipboard retry 或 QuickClip recovery。→ [Mitigation] 增加 StartupCoordinator 回归测试，覆盖 quickRecord、standardShare、disabled preference、media attachment 四类路径。

## Migration Plan

此变更不需要数据迁移。部署后新增入口只影响新收到的 Android intent；回滚时移除 manifest 入口和 quickRecord 模式即可恢复旧行为。若实现增加了 payload 字段，`SharePayload.fromArgs` 必须默认旧 payload 为 `standardShare`，保证旧平台和旧测试数据兼容。

## Open Questions

- 真机侧边栏是否会把文本放在 `ACTION_PROCESS_TEXT`、`ClipData`，还是普通 `ACTION_SEND EXTRA_TEXT`，需要实现阶段验证。
- 是否需要专门的 Android activity alias 来给快速记录入口显示独立 label，取决于真机目标列表是否能稳定暴露新增入口。
