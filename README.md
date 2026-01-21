# MemoFlow

English version: [README_EN.md](README_EN.md)

MemoFlow 是一个面向 [memos](https://github.com/usememos/memos) 后端的 Flutter 移动端客户端。本项目为独立的第三方客户端，
与 Memos 官方项目没有任何关系。

## 功能
- 离线优先：本地 SQLite 缓存 + Outbox 重试队列。
- 支持 Markdown、标签和任务清单的 Memo 新建、编辑、搜索、置顶、归档与删除。
- 快速输入：草稿保存、标签建议、双链引用、附件、拍照，以及撤销/重做。
- 附件浏览：图片预览、音频播放、语音备忘录录制。
- 随机复盘与本地统计（按月图表/热力图），支持分享。
- AI 总结报告：可配置 Provider/Model/Prompt，支持分享海报或保存为 Memo。
- 多账号 PAT 登录，支持旧版 Memos 的兼容模式。
- 小组件、应用锁、偏好设置（主题/语言/字体）、Markdown+ZIP 导出。

## 待办事项
- 用户
  - 认证
    - [x] PAT 登录
    - [ ] 密码登录
  - 账号信息
    - [x] 查看账号信息
    - [ ] 编辑账号信息
    - [ ] Webhook 管理
- Memo
  - 基础
    - [x] 新建/编辑/搜索/置顶/归档/删除
    - [x] 评论
  - Markdown
    - [x] 基础渲染
    - [x] 任务清单
    - [x] 代码块高亮
  - 附件
    - [x] 附件浏览
    - [x] 图片预览
    - [x] 音频播放
    - [ ] 附件编辑
  - 互动
    - [x] 点赞/取消点赞
- 其他
  - [x] 离线优先同步
  - [x] AI 总结
  - [x] 多语言（中文/英文）

## 兼容性
- 默认使用 Memos API v1。
- 连接旧版本服务器时可开启“兼容模式”使用旧接口。

## 截图
**登录**

<img src="docs/登录.png" alt="登录" width="320">

**首页**

<img src="docs/首页.png" alt="首页" width="320">

**导航栏**

<img src="docs/导航栏.png" alt="导航栏" width="320">

**设置**

<img src="docs/设置.png" alt="设置" width="320">

## 数据与隐私
- PAT 通过 `flutter_secure_storage` 存储。
- Memo 缓存在本地 SQLite，并通过 Outbox 队列进行同步。
- AI 总结会将选中的 Memo 内容发送至配置的 AI Provider，不会同步到 Memos 后端。

## 说明
- 导出格式为 Markdown 文件打包的 ZIP（暂未支持导入）。
- 若遇到同步问题，可开启网络日志并在应用内导出诊断信息。

# 致谢
Memos https://github.com/usememos/memos
