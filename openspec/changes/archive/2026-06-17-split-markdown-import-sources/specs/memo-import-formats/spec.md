## ADDED Requirements

### Requirement: Import sources expose explicit supported formats
导入来源选择页 SHALL 展示 Flomo 导出包、侠客日记导出包、Memoflow Markdown 包和通用 Markdown 包四个独立来源，并 SHALL 通过每个标题右侧的圆形问号入口展示该来源支持的文件类型、ZIP 结构和关键规则。

#### Scenario: Import source cards show help without subtitles
- **WHEN** 用户打开导入来源选择页
- **THEN** 页面 SHALL 展示四个独立导入来源
- **AND** 每个来源标题右侧 SHALL 有可点击的圆形问号说明入口
- **AND** 来源卡片 SHALL NOT 展示重复的副标题格式说明

#### Scenario: User opens source format help
- **WHEN** 用户点击任一导入来源的问号说明入口
- **THEN** 系统 SHALL 打开可阅读的格式说明弹窗
- **AND** 弹窗 SHALL 说明当前来源支持的文件类型、ZIP 结构示例和导入限制

### Requirement: Flomo and SwashbucklerDiary imports remain source-specific
Flomo 导出包 SHALL 只按 Flomo HTML 或包含 HTML 的 ZIP 规则处理；侠客日记导出包 SHALL 只按侠客日记 JSON、Markdown 或 TXT ZIP 规则处理。两个来源的帮助和失败说明 SHALL NOT 混用 Markdown 通用包或 Memoflow Markdown 包结构。

#### Scenario: Flomo help describes HTML package support
- **WHEN** 用户打开 Flomo 导出包的格式说明
- **THEN** 系统 SHALL 说明该来源支持 `.html` 或包含 `.html` 的 `.zip`
- **AND** 系统 SHALL NOT 在 Flomo 来源说明中展示通用 Markdown 的 `index.md + assets/` 结构

#### Scenario: SwashbucklerDiary help describes its export formats
- **WHEN** 用户打开侠客日记导出包的格式说明
- **THEN** 系统 SHALL 说明该来源支持侠客日记导出的 JSON、Markdown 或 TXT ZIP
- **AND** 系统 SHALL NOT 在侠客日记来源说明中展示 Memoflow Markdown 的 `memos/*.md` 必需结构

### Requirement: Memoflow Markdown import accepts only Memoflow export structure
Memoflow Markdown 包来源 SHALL 只导入 Memoflow 导出的 Markdown ZIP 结构。合格 ZIP SHALL 至少包含一个位于 `memos/` 目录下且不是 `index.md` 的 `.md` 文件；`index.md` SHALL 仅作为说明文件，不作为 memo 导入。

#### Scenario: User imports valid Memoflow Markdown package
- **WHEN** 用户通过 Memoflow Markdown 包来源选择一个 ZIP，且 ZIP 包含 `memos/memo-001.md`
- **THEN** 系统 SHALL 将 `memos/memo-001.md` 导入为 memo
- **AND** 系统 SHALL 读取可用的 `memos/_meta/memo-001.json` 作为该 memo 的附加元数据
- **AND** 系统 SHALL 将可用的 `attachments/memo-001/*` 作为该 memo 的附件来源

#### Scenario: Memoflow package with only index is rejected
- **WHEN** 用户通过 Memoflow Markdown 包来源选择一个只包含 `index.md` 和 `assets/` 的 ZIP
- **THEN** 系统 SHALL 拒绝导入
- **AND** 失败说明 SHALL 指出未识别到 `memos/*.md`
- **AND** 失败说明 SHALL NOT 提示缺少 HTML 文件

#### Scenario: Memoflow source does not fall back to Flomo HTML
- **WHEN** 用户通过 Memoflow Markdown 包来源选择不符合 Memoflow Markdown 结构的 ZIP
- **THEN** 系统 SHALL 按 Memoflow Markdown 包失败处理
- **AND** 系统 SHALL NOT 尝试继续按 Flomo HTML ZIP 查找 `.html`

### Requirement: Generic Markdown import supports multiple markdown files
通用 Markdown 包来源 SHALL 导入 ZIP 中所有非排除目录下的 `.md` 文件，每个 `.md` 文件 SHALL 成为一条 memo。`index.md` 和 `README.md` SHALL 作为普通 Markdown memo 导入；目录名 SHALL NOT 自动转换为标签。

#### Scenario: User imports multiple markdown files
- **WHEN** 用户通过通用 Markdown 包来源选择包含 `index.md`、`README.md`、`note.md` 和 `folder/another.md` 的 ZIP
- **THEN** 系统 SHALL 导入四条 memo
- **AND** 系统 SHALL NOT 根据 `folder/` 目录名生成标签

#### Scenario: Generic markdown skips resource and hidden directories
- **WHEN** 通用 Markdown ZIP 包含 `assets/ignored.md`、`.obsidian/config.md`、`.git/info.md`、`__MACOSX/meta.md` 和 `.hidden/note.md`
- **THEN** 系统 SHALL NOT 将这些路径下的 `.md` 文件导入为 memo

#### Scenario: Generic markdown reads supported front matter
- **WHEN** 通用 Markdown 文件包含 `created`、`updated`、`tags`、`pinned` 或 `visibility` front matter
- **THEN** 系统 SHALL 将这些字段应用到导入 memo 的时间、标签、置顶状态和可见性
- **AND** 系统 SHALL NOT 将这些 front matter 元数据泄漏到 memo 正文中

### Requirement: Generic Markdown import converts referenced assets to attachments
通用 Markdown 包来源 SHALL 识别 Markdown image、Markdown link、HTML `img`、HTML `audio` 和 HTML `video` 中可解析到 ZIP 内 `assets/` 文件的本地资源引用，将对应文件作为附件导入，并从 memo 正文中移除对应本地资源引用。远程 URL SHALL 保留在正文中。

#### Scenario: User imports markdown with referenced assets
- **WHEN** 通用 Markdown 文件引用 `assets/photo.png` 和 `assets/doc.pdf`，且这些文件存在于 ZIP 中
- **THEN** 系统 SHALL 将这些文件作为该 memo 的附件导入
- **AND** 系统 SHALL 从 memo 正文中移除对应本地资源路径引用

#### Scenario: Remote markdown resources are preserved
- **WHEN** 通用 Markdown 文件包含 `https://example.com/image.png` 或其他远程 URL
- **THEN** 系统 SHALL 保留这些远程 URL 在 memo 正文中
- **AND** 系统 SHALL NOT 尝试将远程 URL 作为 ZIP 附件导入

#### Scenario: Unreferenced assets are ignored
- **WHEN** 通用 Markdown ZIP 包含 `assets/unused.pdf`，但没有任何导入的 `.md` 文件引用它
- **THEN** 系统 SHALL NOT 将 `assets/unused.pdf` 作为附件导入

### Requirement: Import failures show source-specific structure guidance
导入失败时系统 SHALL 使用弹窗展示失败原因和当前来源的合格结构说明。失败弹窗 SHALL 使用当前用户选择的来源决定说明内容，而不是根据其他来源的回退逻辑决定错误文案。

#### Scenario: Generic markdown import fails without markdown files
- **WHEN** 用户通过通用 Markdown 包来源选择不包含可导入 `.md` 文件的 ZIP
- **THEN** 系统 SHALL 展示导入失败弹窗
- **AND** 弹窗 SHALL 说明 ZIP 需要包含至少一个可导入 `.md` 文件
- **AND** 弹窗 SHALL 展示通用 Markdown 包结构示例

#### Scenario: Failure dialog returns to source selection
- **WHEN** 用户关闭导入失败弹窗
- **THEN** 系统 SHALL 返回导入来源选择页
- **AND** 用户 SHALL 能够重新选择同一来源并挑选另一个文件

### Requirement: Import format behavior preserves module boundaries
导入格式说明、ZIP 结构验证、Markdown 资源解析和 memo 写入 SHALL 保持清晰 owner。UI SHALL 只展示来源、帮助和失败弹窗；可复用格式判断和解析逻辑 SHALL NOT 隐藏在 screen/widget 文件中。

#### Scenario: Import implementation does not introduce reverse dependencies
- **WHEN** 实现导入来源拆分、通用 Markdown 解析和失败弹窗
- **THEN** `state`、`application` 和 `core` 层 SHALL NOT 新增对 `features/*` 的 imports
- **AND** 导入解析规则 SHALL 由 service/controller/helper 层覆盖测试，而不是只通过 UI widget 间接验证
