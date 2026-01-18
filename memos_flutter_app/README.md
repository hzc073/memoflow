# MemoFlow

| English | 中文 |
| --- | --- |
| MemoFlow is a Flutter mobile client for the Memos backend. It is an independent, third-party project and is not affiliated with or endorsed by the official Memos project. | MemoFlow 是一个面向 Memos 后端的 Flutter 移动端客户端。本项目为独立的第三方客户端，与 Memos 官方项目没有任何关系，也未获得其认可或背书。 |

## Features / 功能

| English | 中文 |
| --- | --- |
| - Offline-first sync with local SQLite storage and an outbox queue for retries.<br>- Create, edit, search, pin, archive, and delete memos with Markdown, tags, and tasks.<br>- Quick input sheet with drafts, tag suggestions, memo links, attachments, camera capture, and undo/redo.<br>- Attachments browser with image preview and audio playback; voice memo recording.<br>- Random daily review and local stats (monthly charts and activity heatmap) with sharing.<br>- AI summary reports with configurable provider/model/prompt; share poster or save as memo.<br>- Multi-account PAT login plus legacy API compatibility mode for older Memos servers.<br>- Widgets, app lock, preferences (theme, language, fonts), and Markdown+ZIP export. | - 离线优先：本地 SQLite 缓存 + Outbox 重试队列。<br>- 支持 Markdown、标签和任务清单的 Memo 新建、编辑、搜索、置顶、归档与删除。<br>- 快速输入：草稿保存、标签建议、双链引用、附件、拍照，以及撤销/重做。<br>- 附件浏览：图片预览、音频播放、语音备忘录录制。<br>- 随机复盘与本地统计（按月图表/热力图），支持分享。<br>- AI 总结报告：可配置 Provider/Model/Prompt，支持分享海报或保存为 Memo。<br>- 多账号 PAT 登录，支持旧版 Memos 的兼容模式。<br>- 小组件、应用锁、偏好设置（主题/语言/字体）、Markdown+ZIP 导出。 |

## Compatibility / 兼容性

| English | 中文 |
| --- | --- |
| - Uses Memos API v1 by default.<br>- Enable Compatibility Mode for legacy endpoints when connecting to older servers. | - 默认使用 Memos API v1。<br>- 连接旧版本服务器时可开启“兼容模式”使用旧接口。 |

## Requirements / 运行要求

| English | 中文 |
| --- | --- |
| - Flutter SDK (Dart >= 3.10.4).<br>- A running Memos server and a Personal Access Token (PAT). | - Flutter SDK（Dart >= 3.10.4）。<br>- 可访问的 Memos 服务器与个人访问令牌（PAT）。 |

## Run locally / 本地运行

| English | 中文 |
| --- | --- |
| ```sh<br>cd memos_flutter_app<br>flutter pub get<br>flutter run<br>``` | ```sh<br>cd memos_flutter_app<br>flutter pub get<br>flutter run<br>``` |

## Data and privacy / 数据与隐私

| English | 中文 |
| --- | --- |
| - Personal Access Tokens are stored via `flutter_secure_storage`.<br>- Memos are cached in a local SQLite database and synced via an outbox queue.<br>- AI summary sends selected memo content to the configured AI provider; it is not synced to the Memos backend. | - PAT 通过 `flutter_secure_storage` 存储。<br>- Memo 缓存在本地 SQLite，并通过 Outbox 队列进行同步。<br>- AI 总结会将选中的 Memo 内容发送至配置的 AI Provider，不会同步到 Memos 后端。 |

## Notes / 说明

| English | 中文 |
| --- | --- |
| - Export outputs Markdown files inside a ZIP archive (import is not implemented yet).<br>- If you run into sync issues, enable network logging and export diagnostics from the app. | - 导出格式为 Markdown 文件打包的 ZIP（暂未支持导入）。<br>- 若遇到同步问题，可开启网络日志并在应用内导出诊断信息。 |
