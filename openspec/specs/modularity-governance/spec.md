## Purpose

Define the long-term architecture governance rules that quantify modularity, control phase transitions, and prevent maintainability regressions across planning, implementation, and automated verification.
## Requirements
### Requirement: Project defines a quantified modularity phase
The project MUST declare an explicit architecture phase for future planning and implementation. The phase MUST be either `evolve_modularity` or `preserve_modularity`.

The preserve-phase gate SHALL require both:
- a quantified modularity checklist score of at least `8/10`
- satisfaction of every critical checklist item

The critical checklist items MUST be:
- no `state -> features` reverse dependencies
- no `application -> features` reverse dependencies
- no `core -> state|application|features` upward dependencies except explicitly approved adapters
- no reused shared domain logic hidden inside screen or widget files

The full quantified checklist MUST contain exactly these 10 items:
- `1.` no `state -> features` reverse dependencies
- `2.` no `application -> features` reverse dependencies
- `3.` no `core -> state|application|features` upward dependencies except explicitly approved adapters
- `4.` no reused shared domain logic hidden inside screen or widget files
- `5.` `app.dart` and `main.dart` primarily act as composition roots
- `6.` feature-to-feature collaboration prefers boundary, registry, or provider seams over direct screen imports
- `7.` touched write paths have clear owners such as services, repositories, or mutation seams
- `8.` architecture guardrail tests protect the highest-risk dependency directions
- `9.` OpenSpec artifacts document the active architecture phase and expected modularity behavior
- `10.` every change touching a coupled area leaves that area equal or better structured than before

#### Scenario: Project stays in evolve phase below threshold
- **WHEN** the quantified modularity checklist score is below `8/10`
- **THEN** the active architecture phase MUST remain `evolve_modularity`

#### Scenario: Project stays in evolve phase when a critical item fails
- **WHEN** the quantified modularity checklist score is at least `8/10` but any critical item is not satisfied
- **THEN** the active architecture phase MUST remain `evolve_modularity`

#### Scenario: Project may enter preserve phase
- **WHEN** the quantified modularity checklist score is at least `8/10` and every critical item is satisfied
- **THEN** the project MAY change the active architecture phase to `preserve_modularity`

### Requirement: Evolve phase improves touched hotspots
While the active architecture phase is `evolve_modularity`, any bug fix, feature addition, or refactor that touches a coupling hotspot MUST leave the touched area equal or better structured than before.

During `evolve_modularity`, a compliant touched-area improvement MUST include at least one of the following:
- remove or isolate a reverse dependency
- extract shared logic into a more stable seam
- move UI-specific logic or types out of lower layers
- add a guardrail that prevents the touched coupling from worsening

#### Scenario: Change touches a coupling hotspot during evolve phase
- **WHEN** a change modifies code in a known coupling hotspot during `evolve_modularity`
- **THEN** the change MUST include a touched-area modularity improvement or a guardrail that prevents regression

#### Scenario: Change is localized during evolve phase
- **WHEN** a change does not touch a relevant coupling hotspot during `evolve_modularity`
- **THEN** the change MUST NOT introduce new reverse dependencies or make existing boundaries worse

### Requirement: Preserve phase maintains stable boundaries
While the active architecture phase is `preserve_modularity`, new work MUST preserve existing modular boundaries and MUST NOT introduce architecture regressions.

The following SHALL be treated as regressions during `preserve_modularity` unless the repository explicitly approves and documents an adapter exception:
- new `state -> features` dependencies
- new `application -> features` dependencies
- new `core -> state|application|features` upward dependencies
- new shared business or domain logic embedded in screens or widgets

#### Scenario: New feature is added during preserve phase
- **WHEN** a feature is added while the active architecture phase is `preserve_modularity`
- **THEN** the implementation MUST use existing seams, registries, provider boundaries, or owned services without introducing new reverse dependencies

#### Scenario: Existing feature is refactored during preserve phase
- **WHEN** an existing feature is refactored while the active architecture phase is `preserve_modularity`
- **THEN** the change MUST maintain or improve the current modular boundaries and MUST NOT reduce maintainability

### Requirement: Governance is enforced at four layers
The repository MUST place modularity governance constraints across execution rules, planning rules, architecture contract files, and automated guardrails.

The four required enforcement layers SHALL be:
- `AGENTS.md` for execution-time collaboration behavior
- `openspec/config.yaml` for planning and artifact-generation rules
- `openspec/specs/modularity-governance/spec.md` for the long-term normative architecture contract
- `memos_flutter_app/test/architecture/...` for automated high-risk boundary guardrails

#### Scenario: New change is proposed
- **WHEN** a new OpenSpec change is proposed
- **THEN** the generated planning artifacts MUST inherit the active architecture phase and modularity rules from `openspec/config.yaml`

#### Scenario: Code is implemented
- **WHEN** code changes are implemented
- **THEN** execution behavior MUST follow `AGENTS.md` and applicable architecture guardrails MUST protect the highest-risk dependency directions

### Requirement: Phase state and checklist remain reviewable
The active architecture phase, quantified checklist, critical items, and preserve-phase gate MUST be stored in repository-visible documentation so contributors do not rely on chat history or memory.

#### Scenario: Contributor starts planning
- **WHEN** a contributor begins planning or implementing a change
- **THEN** the contributor MUST be able to determine the active architecture phase and checklist gate from repository files

#### Scenario: Team considers a phase transition
- **WHEN** the team wants to transition from `evolve_modularity` to `preserve_modularity`
- **THEN** the change MUST update the phase declaration, supporting documentation, and relevant guardrail tests together

### Requirement: Navigation host fixes preserve feature boundaries
While the active architecture phase is `evolve_modularity`, changes that modify the home navigation host or feature screens participating in `HomeEmbeddedNavigationHost` back handling MUST preserve the host seam as the collaboration boundary. Such changes MUST NOT introduce new `state -> features`, `application -> features`, or `core -> features` dependencies, and MUST include a focused guardrail when the touched behavior has caused or could cause route recursion.

#### Scenario: Overlay back fix touches feature and home code
- **WHEN** a change fixes back behavior involving `HomeEmbeddedNavigationHost` and feature screens during `evolve_modularity`
- **THEN** the implementation MUST keep navigation coordination owned by the home host seam rather than adding direct feature-to-feature or lower-layer shortcuts

#### Scenario: Back recursion risk is identified
- **WHEN** an OpenSpec change identifies a route recursion or ANR risk in home navigation behavior
- **THEN** the implementation MUST add or tighten a test guardrail that fails if the same back action repeatedly re-enters the same route pop callback

