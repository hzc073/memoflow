## Why

当前仓库已经出现明显的跨层耦合与边界回流：`state -> features`、`application -> features`、以及部分 `core -> higher-layer` 依赖已经存在，导致后续修复 bug、增加功能、调整行为时很容易扩大影响面。现在需要把“边改边模块化”从临时口头要求，提升为可复用、可判断、可验证的长期规则。

## What Changes

- 建立一套长期有效的 `modularity governance` 规则，覆盖 `AGENTS.md`、`openspec/config.yaml`、`openspec/specs/.../spec.md` 与 `architecture tests` 四个层次。
- 将“模块化率 80%”从模糊表述量化为 checklist-based gate，避免后续协作中出现理解偏差。
- 定义两个阶段：
  - `evolve_modularity`：模块化未达标时，修 bug / 加功能 / 改代码必须同步降低已触达区域的耦合。
  - `preserve_modularity`：模块化达标后，新增与修改必须保持既有边界，不得破坏可维护性。
- 规定不同位置应承担的约束职责：
  - `AGENTS.md`：执行型协作规则
  - `openspec/config.yaml`：artifact 生成约束
  - `openspec/specs/.../spec.md`：长期架构契约
  - `architecture tests`：自动化 guardrail
- 形成一套可持续演进的判断清单，用于决定项目当前处于哪个阶段，以及每次改动是否满足治理要求。

## Capabilities

### New Capabilities
- `modularity-governance`: Define quantified modularity phases, boundary rules, and multi-layer enforcement guidance for planning, implementation, and architecture verification.

### Modified Capabilities
- None.

## Impact

- Affected planning/config files: `openspec/config.yaml`, `openspec/project.md`
- Affected repository governance: `AGENTS.md`
- Affected long-term architecture contract: `openspec/specs/.../spec.md`
- Affected automated verification: `memos_flutter_app/test/architecture/...`
- Affected developer workflow: future bug fixes, feature additions, and refactors must follow quantified modularity phase rules instead of ad hoc instructions
