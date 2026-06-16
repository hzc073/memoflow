## Why

当前“从 Markdown 导入”的入口文案过宽，但实际实现只在特定目录结构下识别 Memoflow Markdown 导出包；当用户选择普通 Markdown ZIP 时，流程可能回退到 Flomo HTML ZIP 分支并提示“未找到 HTML 文件”，导致失败原因和用户选择不匹配。现在需要把导入来源、支持格式和失败说明对齐，让用户在选择前和失败后都能明确知道 ZIP 结构要求。

## What Changes

- 将现有“从 Markdown 导入”入口重命名并收窄为“Memoflow Markdown 包”，只支持 Memoflow 导出的 `memos/*.md`、可选 `memos/_meta/*.json`、可选 `attachments/<memoUid>/*` 结构。
- 新增“通用 Markdown 包”入口，支持 ZIP 内多个 `.md` 文件，包括 `index.md`、`README.md` 和普通子目录中的 `.md` 文件。
- 通用 Markdown 包不把目录名转换为标签；支持读取 front matter 中的 `created`、`updated`、`tags`、`pinned`、`visibility`。
- 通用 Markdown 包解析本地资源引用，将被引用的 `assets/` 资源作为附件导入，并从 memo 正文中移除本地资源引用；远程 URL 保留。
- 移除导入来源卡片下方说明文字，改为每个导入标题右侧提供圆形问号提示入口。
- 每个问号提示展示该导入来源支持的文件类型、ZIP 结构示例和关键规则。
- 导入失败时使用弹窗展示失败原因，并附带当前入口的合格结构说明；失败提示不得再跨来源误报，例如 Markdown 包失败不提示缺少 HTML 文件。
- 不引入商业、订阅、付费、StoreKit 或私有 overlay 逻辑。

## Capabilities

### New Capabilities

- `memo-import-formats`: 定义 memo 导入来源、支持格式、Markdown ZIP 结构识别、导入说明和失败说明行为。

### Modified Capabilities

- None.

## Impact

- Affected runtime code: `memos_flutter_app/lib/features/import/import_flow_screens.dart`, `memos_flutter_app/lib/features/import/*_import_service.dart`, `memos_flutter_app/lib/state/memos/*import*_controller.dart`, import-related localization files under `memos_flutter_app/lib/i18n/`.
- Affected tests: import source widget tests, Markdown/Memoflow/Flomo/SwashbucklerDiary import controller tests, localization or copy smoke tests where applicable.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 4, item 7, item 8, and item 10.
- Scoped modularity improvement: shared import-format descriptions, source validation, and Markdown ZIP parsing rules should live behind reusable import models/services rather than being duplicated inside screen widgets; touched import write paths must keep clear service/controller ownership and avoid new lower-layer imports from `features/*`.
