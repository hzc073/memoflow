## 1. 来源模型与文案

- [x] 1.1 将 `ImportSourceKind` 拆为 Flomo、侠客日记、Memoflow Markdown、通用 Markdown 四个显式来源。
- [x] 1.2 增加导入来源格式 descriptor，集中维护标题、帮助说明、失败结构示例和文件结构文本。
- [x] 1.3 更新 i18n keys，覆盖四个导入来源标题、问号说明、失败弹窗标题、来源内失败原因和结构示例。
- [x] 1.4 移除导入来源卡片副标题说明，保留标题、图标、问号帮助入口和进入箭头。

## 2. Memoflow Markdown 包收窄

- [x] 2.1 将现有 Memoflow Markdown ZIP 识别从 Flomo HTML ZIP fallback 中拆出或以显式来源参数隔离。
- [x] 2.2 确保 Memoflow Markdown 包只接受至少一个 `memos/*.md`，且 `index.md` 不作为 memo 导入。
- [x] 2.3 确保 Memoflow Markdown 失败时返回来源内失败原因，不再回退查找 `.html`。
- [x] 2.4 保持现有 `memos/_meta/*.json` 和 `attachments/<memoUid>/*` 导入行为不回退。

## 3. 通用 Markdown 包导入

- [x] 3.1 新增通用 Markdown ZIP 解析 helper/service，扫描非排除目录下所有 `.md` 文件。
- [x] 3.2 支持 `index.md`、`README.md`、普通子目录 `.md` 作为 memo 导入，并跳过 `assets/`、`.obsidian/`、`.git/`、`__MACOSX/` 和隐藏目录。
- [x] 3.3 解析通用 Markdown front matter 中的 `created`、`updated`、`tags`、`pinned`、`visibility`，并确保 front matter 不进入正文。
- [x] 3.4 识别 Markdown image/link 与 HTML `img`、`audio`、`video` 的本地 `assets/` 引用，导入被引用文件为附件。
- [x] 3.5 从通用 Markdown 正文移除已导入的本地资源引用，保留远程 URL 和无法解析的本地引用。
- [x] 3.6 复用现有 memo 持久化、附件 staging 和 remote sync guard，避免复制写入逻辑。

## 4. UI 帮助与失败弹窗

- [x] 4.1 在每个导入来源标题右侧增加圆形问号按钮，点击后展示当前来源格式说明弹窗。
- [x] 4.2 将 `ImportException` 和未知错误从 SnackBar 改为平台弹窗，弹窗展示失败原因和当前来源合格结构。
- [x] 4.3 失败弹窗关闭后返回导入来源选择页，并允许用户重新选择来源和文件。
- [x] 4.4 保持取消导入使用现有轻量 toast 行为，不混入结构说明弹窗。

## 5. 模块边界与测试

- [x] 5.1 为 Memoflow Markdown 来源增加 controller/service tests，覆盖有效结构、只有 `index.md`、错误结构不提示 HTML。
- [x] 5.2 为通用 Markdown 来源增加 tests，覆盖多个 `.md`、`README.md` 导入、排除目录、front matter、assets 附件和未引用 assets 跳过。
- [x] 5.3 为 Flomo 和侠客日记来源增加或更新回归 tests，确认既有格式支持不变且说明内容不串源。
- [x] 5.4 更新 `ImportSourceScreen` widget tests，验证四个来源、无副标题、问号帮助弹窗和失败弹窗结构说明。
- [x] 5.5 增加或更新架构/guardrail 测试，确保新增导入解析 helper 不位于 screen/widget 文件，且 `state`、`application`、`core` 不新增 `features/*` imports。
- [x] 5.6 运行 `flutter test test/features/import test/state/memos --reporter expanded` 或等价 focused tests。
- [x] 5.7 在 `memos_flutter_app` 运行 `flutter analyze` 和 `flutter test`，记录任何无法完成的环境限制。
