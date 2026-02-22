# MemoFlow

<p align="center">
  <img src="docs/memoflow-logo.png" alt="MemoFlow Logo" width="120">
</p>

<p align="center">
  <a href="README_EN.md">English</a> |
  <a href="https://memoflow.hzc073.com/">官网</a> |
  <a href="https://memoflow.hzc073.com/help/">帮助中心</a>
</p>

MemoFlow 是一个面向 [memos](https://github.com/usememos/memos) 后端的 Flutter 移动端客户端。

>本项目为独立的第三方客户端，
与 Memos 官方项目没有任何关系。

## 功能
- 登录与版本适配：支持账号密码/PAT 两种登录方式，登录前可选择并探测 Memos API 版本（0.21~0.26）。
- 离线优先：本地 SQLite 缓存 + Outbox 重试队列，支持同步队列查看与重试。
- Memo 全流程：新建、编辑、搜索、置顶、归档、删除、标签过滤、Explore 浏览。
- Markdown 与任务清单：支持常用 Markdown 渲染、任务列表进度展示、双链引用与关联跳转。
- 多媒体输入与预览：支持附件上传、拍照、语音录制、图片/音频/视频预览与下载。
- 版本历史与回收站：支持 Memo 历史版本查看/恢复，回收站恢复或永久删除。
- 提醒系统：支持 Memo 提醒、测试提醒、勿扰时段、铃声/震动等提醒配置。
- 导入导出：支持 Markdown+ZIP 导出，支持 flomo/Markdown ZIP 导入。
- 本地库模式：支持添加并扫描本地库，与服务器模式共存切换。
- WebDAV 能力：支持 WebDAV 同步、备份/恢复、保留策略与恢复码流程。
- AI 与复盘统计：支持 AI 总结、随机复盘、统计与热力图展示。
- 体验与个性化：支持通知中心、小组件、应用锁、主题/语言/字体等偏好设置。

## 待办事项
- 用户
  - 认证
    - [x] PAT 登录
  - 账号信息
    - [x] 查看账号信息
    - [x] 编辑账号信息
    - [x] Webhook 管理
- Memo
  - 基础
    - [x] 新建/编辑/搜索/置顶/归档/删除
  - Markdown
    - [x] 基础渲染:标题、引用、分割线、加粗、斜体、行内代码、代码块、无序/有序列表、链接、图片
    - [x] 自定义扩展渲染：删除线、任务列表、表格、脚注、高亮、下划线用内联 HTML
    - [ ] LaTeX公式
  - 附件
    - [x] 附件浏览
    - [x] 图片预览
    - [x] 音频播放
    - [ ] 附件编辑
  - 互动
    - [x] 点赞/评论
- 其他
  - [x] 离线优先同步
  - [ ] 单机模式
  - [x] AI 总结
  - [ ] 语音转文字
  - [ ] 自定义快速工具
  - [x] 任务事项进度条
  - [ ] 多语言（对齐 Memos 后端语言包，33 项）
    <details>
    <summary>语言列表（点击展开）</summary>

    - [ ] `ar` 阿拉伯语
    - [ ] `ca` 加泰罗尼亚语
    - [ ] `cs` 捷克语
    - [x] `de` 德语
    - [x] `en` 英语
    - [ ] `en-GB` 英式英语
    - [ ] `es` 西班牙语
    - [ ] `fa` 波斯语
    - [ ] `fr` 法语
    - [ ] `gl` 加利西亚语
    - [ ] `hi` 印地语
    - [ ] `hr` 克罗地亚语
    - [ ] `hu` 匈牙利语
    - [ ] `id` 印度尼西亚语
    - [ ] `it` 意大利语
    - [x] `ja` 日语
    - [ ] `ka-GE` 格鲁吉亚语
    - [ ] `ko` 韩语
    - [ ] `mr` 马拉地语
    - [ ] `nb` 挪威博克马尔语
    - [ ] `nl` 荷兰语
    - [ ] `pl` 波兰语
    - [ ] `pt-PT` 葡萄牙语（葡萄牙）
    - [ ] `pt-BR` 葡萄牙语（巴西）
    - [ ] `ru` 俄语
    - [ ] `sl` 斯洛文尼亚语
    - [ ] `sv` 瑞典语
    - [ ] `th` 泰语
    - [ ] `tr` 土耳其语
    - [ ] `uk` 乌克兰语
    - [ ] `vi` 越南语
    - [x] `zh-Hans` 简体中文
    - [x] `zh-Hant` 繁体中文（当前实现：`zh-Hant-TW`）

    </details>

## 截图

<p align="center">
  <img src="docs/登录.png" alt="登录" width="24%">
  <img src="docs/首页.png" alt="首页" width="24%">
  <img src="docs/导航栏.png" alt="导航栏" width="24%">
  <img src="docs/设置.png" alt="设置" width="24%">
</p>

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=hzc073/memoflow&type=Date)](https://www.star-history.com/#hzc073/memoflow&Date)

# 致谢
[Memos](https://github.com/usememos/memos)
