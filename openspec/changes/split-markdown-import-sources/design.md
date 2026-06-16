## Context

当前 `ImportSourceScreen` 只有 `flomoLike` 和 `swashbucklerDiary` 两类运行入口，其中“从 Markdown 导入”也走 `flomoLike`。`FlomoImportController` 在处理 ZIP 时先尝试识别 Memoflow Markdown 结构，再回退到 Flomo HTML ZIP，因此普通 Markdown ZIP 失败时可能展示 HTML 相关错误。导入来源、用户文案、结构验证和失败提示没有一一对应。

本变更发生在 `evolve_modularity` 阶段。触达的耦合风险主要是：导入解析属于可复用业务逻辑，不应继续隐藏在 screen/widget 中；导入写入路径需要保持 controller/service owner；UI 只能负责展示来源、帮助和失败弹窗。

当前依赖方向：

```text
features/import/import_flow_screens.dart
  ├── calls features/import/flomo_import_service.dart
  └── calls features/import/swashbuckler_diary_import_service.dart

features/import/*_import_service.dart
  └── delegates to state/memos/*_import_controller.dart

state/memos/*_import_controller.dart
  └── owns parsing, attachment staging, imported memo persistence
```

目标依赖方向保持为：

```text
features/import UI
  └── source-specific import services and UI-only format descriptions
        └── state/memos import controllers / reusable parsing helpers
              └── data/db and stable lower-level helpers
```

实现 MUST NOT introduce new `state -> features`, `application -> features`, or `core -> features` imports.

## Goals / Non-Goals

**Goals:**

- 将导入来源拆为 Flomo 导出包、侠客日记导出包、Memoflow Markdown 包、通用 Markdown 包。
- 每个来源只按自身格式验证、导入和报错，避免跨来源回退。
- 移除来源卡片副标题说明，把结构说明统一放到标题右侧圆形问号弹窗。
- 失败时用弹窗展示当前来源的失败原因和合格结构示例。
- 支持通用 Markdown ZIP 内多个 `.md` 文件，包括 `index.md` 和 `README.md`。
- 支持通用 Markdown 中被引用的 `assets/` 资源作为附件导入，并从正文移除本地资源引用。
- 保持导入解析和持久化在 service/controller/helper 层，避免把格式判断散落在 UI widget。

**Non-Goals:**

- 不改变 Flomo HTML/ZIP 的解析规则。
- 不改变侠客日记 JSON/Markdown/TXT 的解析规则。
- 不支持将目录名自动转换为标签。
- 不导入未被 Markdown 引用的 `assets/` 文件。
- 不新增商业、订阅、付费、StoreKit、entitlement 或私有 overlay 逻辑。
- 不改变远程同步协议和后端 API 路由。

## Decisions

### 1. 使用来源驱动的导入类型，而不是文件内容自动回退

将 `ImportSourceKind` 从宽泛的 `flomoLike` 拆为显式来源，例如 `flomo`, `swashbucklerDiary`, `memoflowMarkdown`, `genericMarkdown`。用户选择哪个来源，`ImportRunScreen` 就调用对应 service/controller；该 controller 只验证自己的格式。

Alternatives considered:

- 继续使用 `flomoLike` 自动识别：实现改动少，但会继续产生“Markdown 入口报 HTML 错误”的根因。
- 单个万能 ZIP 导入器自动判断所有格式：用户入口简单，但失败解释复杂，且多格式误判风险更高。

### 2. 将 Memoflow Markdown 包从 Flomo HTML ZIP 逻辑中拆出

Memoflow Markdown 包应只接受以下结构：

```text
export.zip
├── index.md
├── memos/
│   ├── memo-001.md
│   └── _meta/
│       └── memo-001.json
└── attachments/
    └── memo-001/
        └── image.png
```

`index.md` 只作为说明文件，不作为 memo 导入。至少需要一个 `memos/*.md`。如果缺少 `memos/*.md`，失败提示应说明 Memoflow Markdown 包结构，而不是提示缺少 HTML。

Alternatives considered:

- 保持 `FlomoImportController` 同时处理 Flomo 和 Memoflow：复用方便，但来源语义混杂。
- 迁移为独立 `MemoflowMarkdownImportService`，内部复用现有解析 helper：更符合来源边界，也便于失败提示和测试。

### 3. 新增通用 Markdown ZIP 导入器

通用 Markdown 包以 `.md` 文件为 memo 单位。它应导入非排除目录下的所有 `.md` 文件，包括 `index.md`、`README.md`、普通子目录 Markdown。

跳过目录规则：

```text
assets/**
.obsidian/**
.git/**
__MACOSX/**
任何隐藏目录/**
```

通用 Markdown 不根据目录生成标签。front matter 支持字段限定为 `created`、`updated`、`tags`、`pinned`、`visibility`；其他字段在第一版不参与业务行为。

Alternatives considered:

- 只支持 `index.md`：实现简单，但不满足多个 `.md` 的用户需求。
- 递归导入所有 `.md` 包括 `assets` 和隐藏目录：覆盖广，但容易误导入资源目录、配置目录和系统目录。

### 4. 本地 assets 引用转附件，正文移除本地资源引用

通用 Markdown 导入器应识别：

```md
![图](assets/a.png)
[文件](assets/doc.pdf)
<img src="assets/a.png">
<audio src="assets/a.mp3">
<video src="assets/a.mp4">
```

被解析并存在于 ZIP 内的本地 `assets/` 文件应作为附件导入；正文中的对应本地资源引用应移除。Markdown 普通链接移除资源路径后保留 label 文本。远程 URL、普通 Markdown 文本和无法解析的本地引用保留，以降低误删风险。

资源解析优先级：

```text
1. 相对当前 .md 文件目录解析
2. ZIP 根目录解析
3. ZIP 根目录 assets/ 兜底解析
```

所有路径必须 normalize 并限制在解压根目录内，防止 ZIP 路径穿越。

### 5. 帮助说明和失败说明共享结构描述

每个来源定义一个 UI-only format descriptor，用于：

- 来源标题旁的圆形问号弹窗。
- 导入失败弹窗中的结构说明。
- widget tests 中验证可见文案。

descriptor 可以位于 `features/import` 内，因为它只服务导入 UI；controller 不依赖 descriptor。controller 返回或抛出来源内的失败原因，`ImportRunScreen` 根据 `sourceKind` 拼接失败弹窗。

Alternatives considered:

- controller 直接返回完整本地化帮助文案：会让 state 层承载 UI copy 和结构排版。
- 每个 widget 手写说明：容易重复和漂移，不满足模块化 checklist item 4。

### 6. 失败弹窗替代 SnackBar

`ImportException` 和未知错误都应通过平台弹窗展示；弹窗关闭后返回来源选择页，用户可以重新选择文件。取消导入仍可继续使用轻量 toast。

失败弹窗内容分层：

```text
导入失败
<来源内失败原因>

支持结构：
<当前来源结构示例>
```

这保持了错误反馈的上下文，也避免长结构说明被 SnackBar 截断。

## Risks / Trade-offs

- [Risk] 通用 Markdown 多文件导入可能误导入用户不想导入的 `README.md`。→ Mitigation: 这是本次明确决策；帮助说明必须写明 `README.md` 会作为 memo 导入。
- [Risk] assets 引用解析覆盖不全。→ Mitigation: 第一版只承诺 Markdown image/link 和 HTML img/audio/video；未解析或不存在的本地引用保留在正文，避免静默丢内容。
- [Risk] 拆分来源会触动现有 Flomo/Memoflow 共用路径。→ Mitigation: 增加 focused controller tests，确保 Flomo HTML/ZIP 行为保持不变，Memoflow Markdown 不再回退到 HTML。
- [Risk] 多语言新增文案较多，翻译质量可能不一致。→ Mitigation: 所有 locale 补 key，中文和英文保持准确，其他语言可采用保守直译或英文 fallback 风格。
- [Risk] 在 `evolve_modularity` 阶段把格式规则放进 UI 会扩大隐藏共享逻辑。→ Mitigation: 抽出 import-format descriptor 和通用 Markdown 解析 helper，测试覆盖 helper 行为；不新增 lower-layer to `features/*` imports。

## Migration Plan

1. 引入显式 `ImportSourceKind` 和来源到 service/controller 的分派。
2. 将现有 Markdown 入口文案和行为收窄为 Memoflow Markdown 包。
3. 新增通用 Markdown 导入 service/controller/helper。
4. 新增来源帮助弹窗和失败弹窗，并移除导入卡片副标题。
5. 补充 i18n keys、widget tests、controller tests 和必要 guardrail/focused dependency checks。

Rollback strategy: 若通用 Markdown 导入出现风险，可隐藏或禁用 `genericMarkdown` 入口，同时保留 Memoflow Markdown 和既有 Flomo/侠客日记来源；由于变更不迁移数据库 schema，回滚不需要数据迁移。

## Open Questions

- None. 当前用户决策为：目录不转换标签、所有非排除目录中的 `.md` 包括 `README.md` 都导入、来源卡片说明全部移除。
