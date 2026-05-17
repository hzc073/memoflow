## 1. Quantify the modularity phase

- [x] 1.1 Add an explicit architecture phase declaration to `openspec/config.yaml`
- [x] 1.2 Encode the 10-item modularity checklist and mark the critical items in repository-facing documentation
- [x] 1.3 Assess the current repository against the checklist and record the initial phase as `evolve_modularity` or `preserve_modularity`

## 2. Add execution-time governance rules

- [x] 2.1 Update `AGENTS.md` with phase-aware execution rules for bug fixes, feature additions, and refactors
- [x] 2.2 Add `evolve_modularity` constraints that require touched-area modularity improvements without forcing broad rewrites
- [x] 2.3 Add `preserve_modularity` constraints that forbid new reverse dependencies and architecture regressions

## 3. Add planning-time OpenSpec rules

- [x] 3.1 Update `openspec/config.yaml` `context` so future changes inherit the active architecture phase automatically
- [x] 3.2 Add artifact-specific `rules` for `proposal`, `design`, `specs`, and `tasks` so planning artifacts must discuss modularity impact and boundary handling
- [x] 3.3 Ensure the config wording makes the 80% threshold unambiguous by referencing the quantified checklist instead of a vague percentage only

## 4. Add architecture contract and guardrails

- [x] 4.1 Ensure the `modularity-governance` change spec fully captures the phase model, checklist gate, and four-layer enforcement responsibilities
- [x] 4.2 Add or extend `memos_flutter_app/test/architecture/...` guardrail tests for high-risk dependency directions such as `state -> features`, `application -> features`, and `core -> higher-layer`
- [x] 4.3 Add a regression check that enforces “no new boundary breakage” for future changes, with phase-aware expectations where practical

## 5. Verify rollout readiness

- [x] 5.1 Validate the OpenSpec change artifacts and confirm the generated rules are internally consistent
- [x] 5.2 Run the relevant architecture test subset and confirm the new guardrails behave as intended
- [x] 5.3 Document how and when the project may transition from `evolve_modularity` to `preserve_modularity`
