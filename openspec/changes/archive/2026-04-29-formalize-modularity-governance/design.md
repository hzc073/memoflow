## Context

当前仓库已经具备较清晰的目录分层（如 `features`、`state`、`data`、`application`、`core`），但真实依赖方向并不稳定。探索结果表明，仓库中已经存在一些反向依赖与跨模块回流，例如 `state -> features`、`application -> features`、以及局部 `core -> higher-layer` 情况。这使得后续 bug fix、feature work 与 refactor 往往只能依赖人工提醒“顺手模块化”，缺少稳定、可继承的制度化约束。

本次变更不是直接调整业务代码，而是建立一套长期治理机制，让后续实现工作在不同阶段采用不同策略：
- 模块化不足时：边改边收敛耦合
- 模块化达标后：稳定维护边界，避免回退

该变化横跨 `AGENTS.md`、`openspec/config.yaml`、`openspec/specs/.../spec.md` 与 `memos_flutter_app/test/architecture/...`，属于典型 cross-cutting architecture governance change。

## Goals / Non-Goals

**Goals:**
- 将“模块化率 80%”量化为可判断、可重复使用的标准，而不是模糊口头描述。
- 建立两阶段治理模型：`evolve_modularity` 与 `preserve_modularity`。
- 为不同位置定义明确职责：
  - `AGENTS.md` 负责执行规则
  - `openspec/config.yaml` 负责 planning artifact 约束
  - `openspec/specs/.../spec.md` 负责长期架构契约
  - `architecture tests` 负责自动化 guardrail
- 让后续 bug fix / feature addition / code modification 默认继承这套规则，无需每次重复强调。

**Non-Goals:**
- 本次变更不直接重构 `memos_flutter_app` 业务代码。
- 本次变更不承诺一次性把项目提升到目标模块化水平。
- 本次变更不定义所有实现细节的唯一写法；它定义的是治理边界与验收标准。

## Decisions

### Decision 1: Use a phase-based governance model instead of a free-form “keep modularizing” rule

项目需要的不是单条永远不变的规则，而是随仓库成熟度切换的治理模式。因此采用两个显式阶段：

- `evolve_modularity`
  - 用于模块化尚未达标的阶段
  - 任何触达既有耦合热点的改动，都必须使“触达范围内的结构不比之前更差”
  - 允许小步抽离 shared logic、引入 boundary seam、减少反向依赖

- `preserve_modularity`
  - 用于模块化已达标的阶段
  - 后续变更必须保持既有模块边界
  - 禁止重新引入已治理过的反向依赖或高层回流

之所以不用单一规则，是因为“边改边模块化”适合过渡期，但不适合作为永久默认；成熟后更需要稳定边界而不是持续无目标重构。

### Decision 2: Quantify “80% modularity” with a 10-item checklist plus critical gates

为了避免歧义，定义 `modularity score` 为 10 项检查中满足项的数量。项目进入 `preserve_modularity` 的条件为：

- 总分 `>= 8 / 10`
- 且所有 critical items 全部满足

其中 checklist 如下：

1. **No `state -> features` reverse dependency**
2. **No `application -> features` reverse dependency**
3. **No `core -> state|application|features` upward dependency**, except explicit approved adapters
4. **Shared domain logic is not hidden inside screen/widget files** when it is reused across flows
5. `app.dart` and `main.dart` act primarily as composition roots
6. New feature-to-feature collaboration uses boundary/registry/provider seam instead of direct screen imports
7. Touched write paths have clear owners (service/repository/mutation seam), not scattered direct side effects
8. Architecture guardrail tests exist for the highest-risk dependency directions
9. OpenSpec artifacts document the active architecture phase and expected behavior
10. A change touching a coupled area leaves that area equal-or-better structured than before

Critical items: `1`, `2`, `3`, `4`

理由：
- 仅用 `8/10` 容易掩盖关键边界问题，因此增加 critical gate
- 仅用 critical gate 又不够，需要总分反映整体成熟度

### Decision 3: Split governance responsibility across four enforcement layers

规则需要按“谁消费它”来放置：

- `AGENTS.md`
  - 面向协作执行
  - 约束 AI / human-assisted change behavior
  - 适合写“本次改动必须如何处理耦合”

- `openspec/config.yaml`
  - 面向 artifact generation
  - 约束 proposal / design / specs / tasks 如何描述模块化责任
  - 适合写“在 planning 时必须讨论哪些架构问题”

- `openspec/specs/modularity-governance/spec.md`
  - 面向长期 contract
  - 适合写规范性 `MUST/SHALL` 要求与验收场景

- `memos_flutter_app/test/architecture/...`
  - 面向自动化验证
  - 适合写 forbidden import / guardrail / phase-aware regression checks

这样做比把所有要求都塞到 `AGENTS.md` 更稳定，因为它同时覆盖“执行、规划、契约、验证”四个维度。

### Decision 4: Make phase state explicit and reviewable

活动阶段必须是显式值，而不是默认心照不宣。推荐将当前 phase 放在 `openspec/config.yaml` 的 `context` 中，并在 `AGENTS.md` 中要求执行者以此为准。

推荐表达方式：
- `Architecture phase: evolve_modularity`
- `Architecture phase: preserve_modularity`

这样变更阶段时只需要调整一个显式声明，不必在每次任务中重新口述。

### Decision 5: Prefer “no net regression in touched area” during evolve phase

在 `evolve_modularity` 阶段，不要求每次 bug fix 都完成大规模重构，否则会显著拖慢交付。采用更现实的局部规则：

- 若改动触达耦合热点，必须至少满足以下之一：
  - 抽离一段 shared logic
  - 去掉一条反向依赖
  - 把 UI-specific type/logic 移到更稳定的 seam
  - 增加 guardrail test 防止继续恶化

这样能把模块化工作嵌入日常迭代，而不是额外创建一条永远做不完的大重构项目。

## Risks / Trade-offs

- [Risk] Checklist 过于抽象，执行时仍可能产生理解偏差 → Mitigation: 在 spec 中把 critical items、phase 条件、示例场景全部写成 normative requirements。
- [Risk] 仅靠文档规则无法阻止回退 → Mitigation: 在 `architecture tests` 中加入 forbidden dependency guardrails。
- [Risk] `evolve_modularity` 被滥用为“每次都顺便重构很多” → Mitigation: 明确要求只改善 touched area，不做无边界扩张。
- [Risk] `preserve_modularity` 阶段切换过早，导致仓库仍有隐藏耦合 → Mitigation: 切换前必须逐项核对 10-item checklist，并满足所有 critical items。
- [Risk] 规则过重影响交付节奏 → Mitigation: 采用 phase model；过渡期强调最小增量改善，稳定期强调不回退。

## Migration Plan

1. 在 OpenSpec 变更中定义 capability 与 requirements。
2. 将执行规则落入 `AGENTS.md`，使后续协作默认遵守 phase model。
3. 将 artifact 级规则加入 `openspec/config.yaml`，使未来 proposal/design/tasks 自动讨论模块化影响。
4. 在主 `specs` 中建立 `modularity-governance` 契约，作为长期规范来源。
5. 增加或更新 `architecture tests`，把高风险依赖方向变成自动化检查。
6. 初始阶段默认进入 `evolve_modularity`，待 checklist 达到 `>= 8/10` 且 critical items 全绿后，再切换到 `preserve_modularity`。

Rollback strategy:
- 若规则文本不清晰，可仅回退具体 wording，不回退 phase model 本身。
- 若某条 guardrail 过于严格，可临时调整 test allowlist，但不得删除整体治理机制。

## Open Questions

- `modularity score` 是手工评估记录，还是后续增加半自动扫描脚本来辅助判断？
- `architecture tests` 是否需要读取一个统一 phase source，还是先只固化 dependency guardrails？
- 未来是否需要把 checklist 评估结果记录在单独文档（例如 `docs/architecture/modularity-score.md`）以便团队追踪？
