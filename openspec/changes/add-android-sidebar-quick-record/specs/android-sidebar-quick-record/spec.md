## ADDED Requirements

### Requirement: Android quick record SHALL accept selected or dragged text

系统 SHALL 为 Android 选中文本、侧边栏或拖拽类快速记录来源接收纯文本，并打开现有 memo 输入框让用户确认提交。

#### Scenario: Selected text opens the composer

- **WHEN** Android 通过快速记录入口提供选中文本
- **THEN** MemoFlow SHALL 打开 memo 输入框
- **AND** 输入框内容 SHALL 预填为收到的原始文本
- **AND** 系统 SHALL NOT 自动创建 memo，直到用户确认发送。

#### Scenario: ClipData text opens the composer

- **WHEN** Android 通过快速记录入口提供纯文本 `ClipData`
- **AND** intent 中没有更明确的普通分享文本 payload
- **THEN** MemoFlow SHALL 将该 `ClipData` 文本作为快速记录内容
- **AND** 输入框内容 SHALL 预填为收到的文本。

### Requirement: Android quick record SHALL preserve URLs as plain text

快速记录入口中的 URL SHALL 被视为普通文本，不得触发 QuickClip、网页剪藏、链接预览捕获或后台解析。

#### Scenario: Quick record text contains a URL

- **WHEN** Android 快速记录入口提供文本 `Read https://example.com/a`
- **THEN** MemoFlow SHALL 打开 memo 输入框并预填 `Read https://example.com/a`
- **AND** MemoFlow SHALL NOT 打开 QuickClip sheet
- **AND** MemoFlow SHALL NOT 启动 share capture 或网页剪藏任务。

#### Scenario: Ordinary share URL behavior is preserved

- **WHEN** 普通第三方分享入口提供包含 HTTP(S) URL 的文本
- **THEN** MemoFlow SHALL 保持现有普通分享行为
- **AND** 支持 URL 继续进入 QuickClip 或现有剪藏流程。

### Requirement: Android quick record SHALL accept media attachments

系统 SHALL 支持 Android 快速记录入口接收图片、视频等媒体 URI，并通过现有输入框附件流程让用户确认提交。

#### Scenario: Single media URI opens composer with attachment

- **WHEN** Android 快速记录入口提供一个图片或视频 URI
- **THEN** MemoFlow SHALL 打开 memo 输入框
- **AND** 输入框 SHALL 包含该媒体文件对应的待上传附件
- **AND** 系统 SHALL NOT 自动创建 memo，直到用户确认发送。

#### Scenario: Multiple media URIs open composer with attachments

- **WHEN** Android 快速记录入口提供多个图片或视频 URI
- **THEN** MemoFlow SHALL 打开 memo 输入框
- **AND** 输入框 SHALL 包含每个可读取媒体 URI 对应的待上传附件。

#### Scenario: Unreadable media URI is ignored safely

- **WHEN** Android 快速记录入口提供一个或多个 URI
- **AND** 部分 URI 无法读取或无法缓存为本地临时文件
- **THEN** MemoFlow SHALL 跳过无法读取的 URI
- **AND** MemoFlow SHALL NOT 因单个 URI 失败而崩溃。

### Requirement: Android quick record SHALL reuse third-party share eligibility

Android 快速记录入口 SHALL 复用现有第三方分享的用户偏好和工作区可用性判断。

#### Scenario: Third-party share is disabled

- **WHEN** `thirdPartyShareEnabled` 为 false
- **AND** Android 快速记录入口提供文本或媒体
- **THEN** MemoFlow SHALL NOT 打开 memo 输入框
- **AND** MemoFlow SHALL 使用现有第三方分享禁用反馈行为。

#### Scenario: Workspace is unavailable

- **WHEN** 当前没有可用远程账号或本地工作区
- **AND** Android 快速记录入口提供文本或媒体
- **THEN** MemoFlow SHALL NOT 自动创建 memo
- **AND** MemoFlow SHALL 等待现有启动/工作区可用流程满足后再处理或安全放弃该入口。

### Requirement: Android quick record implementation SHALL preserve architecture boundaries

快速记录实现 SHALL 保持 Android intent 解析、share payload 分流和 memo 输入 UI 的职责分离，并 MUST NOT 引入新的 API、商业逻辑或模块依赖回归。

#### Scenario: API compatibility is unchanged

- **WHEN** Android 快速记录入口被实现
- **THEN** Memos server API request/response models、route adapters 和 version compatibility logic SHALL remain unchanged
- **AND** files under `memos_flutter_app/lib/data/api` and `memos_flutter_app/test/data/api` SHALL NOT be modified for this change.

#### Scenario: Commercial logic is not introduced

- **WHEN** Android 快速记录入口被实现
- **THEN** public app shell SHALL NOT add subscription、billing、entitlement、paywall、StoreKit 或其他商业逻辑。

#### Scenario: Dependency hotspots do not get worse

- **WHEN** Android 快速记录入口触碰现有 share startup flow
- **THEN** implementation SHALL NOT add new `state -> features` reverse dependencies
- **AND** implementation SHALL NOT add new `core -> state|application|features` upward dependencies
- **AND** implementation SHALL NOT expand existing architecture guardrail allowlists unless explicitly approved with matching spec and test updates.
