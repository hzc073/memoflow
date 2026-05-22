## ADDED Requirements

### Requirement: Window chrome safe-area work SHALL be classified as platform shell work
项目 SHALL 将 titlebar、toolbar、traffic-light 避让、caption controls、drag region 和 window-control geometry 的变更视为平台外壳工作；可复用计算可以位于桌面通用层，但不得依赖业务 feature 层。

#### Scenario: 新增窗口控件避让逻辑
- **WHEN** 变更新增或修改 window chrome safe-area、traffic-light inset、caption-control inset 或 desktop titlebar geometry
- **THEN** 该变更必须声明影响平台外壳层，并保持 helper / adapter 不依赖 `features/*`、`state/*`、`application/*` 或 `data/*`

#### Scenario: Coupling hotspot is touched during evolve_modularity
- **WHEN** 该类变更触及 `home`、`settings`、desktop shell 或 macOS Runner
- **THEN** 该变更必须通过集中 seam、复用 helper、减少页面级平台分支或增加 guardrail，让 touched area equal or better structured
