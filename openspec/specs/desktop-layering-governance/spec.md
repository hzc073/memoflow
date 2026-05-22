# desktop-layering-governance Specification

## Purpose
TBD - created by archiving change desktop-platform-split-and-private-macos. Update Purpose after archive.
## Requirements
### Requirement: 所有相关代码 SHALL 分配到一个架构层
项目 SHALL 将桌面相关应用代码和未来桌面功能工作分类到四个层级之一：共享业务、桌面通用、平台外壳或私有商业。

#### Scenario: 提出新的桌面功能
- **WHEN** 引入新的桌面向功能或重构
- **THEN** 该变更必须在实现开始前声明影响的架构层级

### Requirement: 共享业务逻辑 SHALL 保持平台中立
共享业务逻辑 SHALL 负责不天然绑定到单一桌面外壳或私有商业运行时的应用行为，包括领域行为、数据持久化、同步、API 编排和状态管理。

#### Scenario: 能力不属于外壳专属
- **WHEN** 某项能力可以在 Android、Windows 和 macOS 上以相同方式运行
- **THEN** 其主要行为必须在平台外壳层和私有商业层之外实现

### Requirement: 桌面通用逻辑 MUST NOT 依赖单一平台外壳
桌面通用逻辑 SHALL 负责 Windows 和 macOS 共享的跨桌面交互模型、布局状态模型、快捷键抽象、窗口协调模型和其他可复用桌面行为，并 MUST NOT 依赖单一平台外壳。

#### Scenario: 桌面行为在 Windows 和 macOS 之间共享
- **WHEN** 某个行为在两个桌面平台上都需要，且语义基本一致
- **THEN** 该行为必须在桌面通用层实现，而不是直接放入 Windows 或 macOS 外壳代码

### Requirement: 平台外壳代码 SHALL 负责平台专属的顶层体验
平台外壳代码 SHALL 负责平台专属的外观和集成，例如标题栏、工具栏、导航外壳、菜单约定、系统对话框、平台窗口行为和其他顶层平台 UX 关注点。

#### Scenario: 功能改变平台外壳
- **WHEN** 某个变更主要影响标题栏行为、工具栏组成、窗口控件、系统菜单或外壳导航约定
- **THEN** 该变更必须被视为平台外壳工作，而不是桌面通用工作

### Requirement: Titlebar navigation context SHALL belong to the platform shell layer
Titlebar title visibility, native window-control avoidance, native close dispatch, and top-level navigation context rules SHALL be treated as platform shell concerns rather than shared business logic or feature-page behavior.

#### Scenario: Change affects titlebar context
- **WHEN** a change decides whether a desktop titlebar shows, hides, relocates, or suppresses a page title based on platform, window chrome, navigation mode, or sidebar visibility
- **THEN** the change MUST be classified as platform shell work

#### Scenario: Change affects native close dispatch
- **WHEN** a change decides whether native window close dismisses a secondary app route or closes/hides the window
- **THEN** the change MUST be classified as platform shell work

#### Scenario: Shared business layer stays platform neutral
- **WHEN** titlebar navigation-context rules are implemented
- **THEN** shared business, data, API, synchronization, repository, and state layers MUST NOT gain imports or flags for macOS traffic lights, Windows caption controls, expanded sidebar title suppression, secondary-route native close dispatch, or other platform shell chrome details

### Requirement: Feature pages SHALL NOT own native window chrome title rules
Feature pages SHALL avoid page-local macOS traffic-light offsets, titlebar magic padding, and duplicated top-leading title suppression logic when participating in a desktop shell.

#### Scenario: Feature page touches desktop page chrome
- **WHEN** a feature page adds or changes desktop title, leading action, trailing action, command bar, drawer destination, or shell slot behavior
- **THEN** it SHALL route titlebar placement and title visibility through the desktop shell host, platform adapter, or equivalent centralized seam

#### Scenario: Feature page touches top-level toolbar height
- **WHEN** a feature page adds or changes macOS expanded-sidebar top-level titlebar, toolbar, AppBar, or body-start spacing
- **THEN** it SHALL route spacer height and titlebar omission behavior through the desktop shell host, platform adapter, or equivalent centralized seam instead of using page-local magic heights

#### Scenario: Feature page touches secondary route dismissal
- **WHEN** a feature page adds or changes secondary desktop route dismissal behavior
- **THEN** it SHALL route macOS native close behavior through the desktop shell host, platform adapter, or equivalent centralized seam

#### Scenario: Coupled area remains equal or better structured
- **WHEN** implementation touches `home`, `settings`, `memos`, or desktop shell code for titlebar navigation context
- **THEN** it MUST remove, isolate, or guard against page-local platform branching so the touched area remains equal or better structured under `evolve_modularity`

### Requirement: Titlebar navigation context guardrails SHALL prevent boundary regressions
The system SHALL protect titlebar navigation context rules with tests, smoke checklists, or architecture guardrails that prevent feature-page drift and lower-layer platform leakage.

#### Scenario: Guardrail scans lower layers
- **WHEN** titlebar navigation context implementation adds helpers, policies, or tests
- **THEN** guardrails SHALL verify that `state`, `application`, `data`, and lower-level shared business files do not depend on feature pages or platform shell chrome details

#### Scenario: Guardrail catches repeated macOS titlebar fixes
- **WHEN** future changes attempt to fix macOS top-leading title overlap from inside an individual top-level feature page
- **THEN** tests, review checklist entries, or architecture guardrails SHALL direct the fix back to the centralized desktop shell or platform adapter policy

#### Scenario: Guardrail catches page-local native close interception
- **WHEN** future changes attempt to intercept macOS native close from inside an individual feature page
- **THEN** tests, review checklist entries, or architecture guardrails SHALL direct the behavior back to the centralized desktop shell or platform adapter policy

### Requirement: Window chrome safe-area work SHALL be classified as platform shell work
项目 SHALL 将 titlebar、toolbar、traffic-light 避让、caption controls、drag region 和 window-control geometry 的变更视为平台外壳工作；可复用计算可以位于桌面通用层，但不得依赖业务 feature 层。

#### Scenario: 新增窗口控件避让逻辑
- **WHEN** 变更新增或修改 window chrome safe-area、traffic-light inset、caption-control inset 或 desktop titlebar geometry
- **THEN** 该变更必须声明影响平台外壳层，并保持 helper / adapter 不依赖 `features/*`、`state/*`、`application/*` 或 `data/*`

#### Scenario: Coupling hotspot is touched during evolve_modularity
- **WHEN** 该类变更触及 `home`、`settings`、desktop shell 或 macOS Runner
- **THEN** 该变更必须通过集中 seam、复用 helper、减少页面级平台分支或增加 guardrail，让 touched area equal or better structured

