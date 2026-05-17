## ADDED Requirements

### Requirement: Project defines a quantified modularity phase
The project MUST define an explicit architecture phase used for future planning and implementation decisions. The phase MUST be either `evolve_modularity` or `preserve_modularity`.

The project MUST quantify modularity readiness with a 10-item checklist. Entering `preserve_modularity` SHALL require both:
- a checklist score of at least `8/10`
- satisfaction of all critical items

The critical items MUST be:
- no `state -> features` reverse dependencies
- no `application -> features` reverse dependencies
- no `core -> state|application|features` upward dependencies except approved adapters
- no reused shared domain logic hidden inside screen/widget files

The 10-item checklist MUST be:
- `1.` no `state -> features` reverse dependencies
- `2.` no `application -> features` reverse dependencies
- `3.` no `core -> state|application|features` upward dependencies except approved adapters
- `4.` no reused shared domain logic hidden inside screen/widget files
- `5.` `app.dart` and `main.dart` primarily act as composition roots
- `6.` feature-to-feature collaboration prefers boundary, registry, or provider seams over direct screen imports
- `7.` touched write paths have clear owners such as services, repositories, or mutation seams
- `8.` architecture guardrail tests protect the highest-risk dependency directions
- `9.` OpenSpec artifacts document the active architecture phase and expected modularity behavior
- `10.` every change touching a coupled area leaves that area equal or better structured than before

#### Scenario: Project remains in evolve phase below threshold
- **WHEN** the checklist score is below `8/10`
- **THEN** the active architecture phase MUST be `evolve_modularity`

#### Scenario: Project remains in evolve phase when critical items fail
- **WHEN** the checklist score is `8/10` or higher but any critical item is not satisfied
- **THEN** the active architecture phase MUST remain `evolve_modularity`

#### Scenario: Project may enter preserve phase
- **WHEN** the checklist score is `8/10` or higher and all critical items are satisfied
- **THEN** the project MAY switch the active architecture phase to `preserve_modularity`

### Requirement: Changes in evolve phase improve or preserve touched-area modularity
While the active architecture phase is `evolve_modularity`, any bug fix, feature addition, or code modification that touches a coupled area MUST leave the touched area equal or better structured than before.

During `evolve_modularity`, a qualifying improvement MUST include at least one of:
- removing or isolating a reverse dependency
- extracting shared logic into a more stable seam
- moving UI-specific types or behavior out of lower layers
- adding architecture guardrails that prevent the touched coupling from getting worse

#### Scenario: Bug fix touches a coupled area
- **WHEN** a change modifies files in a known coupling hotspot during `evolve_modularity`
- **THEN** the change MUST include at least one touched-area modularity improvement or an explicit guardrail that prevents regression

#### Scenario: Bug fix does not touch a coupled area
- **WHEN** a change is localized and does not touch a known coupling hotspot during `evolve_modularity`
- **THEN** the change MUST NOT introduce new reverse dependencies or worsen existing boundaries

### Requirement: Changes in preserve phase maintain stable boundaries
While the active architecture phase is `preserve_modularity`, new changes MUST preserve the established modular structure and MUST NOT introduce new reverse dependencies or architecture regressions.

The project MUST treat the following as regressions in `preserve_modularity` unless explicitly approved as boundary adapters:
- new `state -> features` dependencies
- new `application -> features` dependencies
- new `core -> state|application|features` dependencies
- new shared business/domain logic embedded inside screens or widgets

#### Scenario: New feature in preserve phase
- **WHEN** a developer adds a new feature while the active architecture phase is `preserve_modularity`
- **THEN** the new feature MUST integrate through existing seams, boundaries, registries, or owned services without introducing new reverse dependencies

#### Scenario: Refactor in preserve phase
- **WHEN** a change refactors an existing module while the active architecture phase is `preserve_modularity`
- **THEN** the change MUST maintain or improve current boundaries and MUST NOT reduce maintainability

### Requirement: Governance rules are enforced at four layers
The project MUST place modularity governance constraints across four layers so that the rules survive future work without repeated ad hoc instruction.

Required layer responsibilities:
- `AGENTS.md` SHALL define execution-time collaboration rules
- `openspec/config.yaml` SHALL define planning and artifact-generation rules
- `openspec/specs/modularity-governance/spec.md` SHALL define the long-term normative architecture contract
- `memos_flutter_app/test/architecture/...` SHALL define automated guardrails for high-risk dependency directions

#### Scenario: Planning a new change
- **WHEN** a new OpenSpec change is proposed
- **THEN** the planning artifacts MUST be guided by phase-aware modularity rules from `openspec/config.yaml`

#### Scenario: Implementing a new change
- **WHEN** code changes are executed
- **THEN** the execution behavior MUST be governed by `AGENTS.md` and verified by architecture guardrails where applicable

### Requirement: Modularity phase and checklist remain reviewable
The active architecture phase and the checklist used to determine it MUST be documented in a reviewable location so that future contributors do not rely on memory or chat history.

The documented checklist MUST enumerate all 10 items and identify which items are critical.

#### Scenario: New contributor starts a change
- **WHEN** a contributor begins planning or implementing a change
- **THEN** the contributor MUST be able to determine the active architecture phase and the checklist criteria from repository documentation

#### Scenario: Phase transition is considered
- **WHEN** the team wants to switch from `evolve_modularity` to `preserve_modularity`
- **THEN** the decision MUST be justified against the documented checklist and critical-item gates
