# AGENTS.md

## Dev environment tips
- The main app lives in `memos_flutter_app`; run Flutter commands from that directory.
- Match CI toolchain when possible: Flutter `3.38.5` (stable) and Dart SDK compatible with `^3.10.4` from `pubspec.yaml`.
- First-time setup:
  - `cd memos_flutter_app`
  - `flutter pub get`
- Useful local build scripts:
  - Android APK: `pwsh .\tool\build_apk.ps1`
  - Windows bundle + installer: `pwsh .\tool\build_windows.ps1`
- If Windows desktop files are missing, run `flutter create --platforms=windows .` in `memos_flutter_app`.

## Testing instructions
- CI PR check is API compatibility tests in `memos_flutter_app/test/data/api`:
  - `flutter test test/data/api --reporter expanded`
- Before opening a PR, run the full local checks in `memos_flutter_app`:
  - `flutter analyze`
  - `flutter test`
- For focused debugging, run a single file:
  - `flutter test test/data/api/server_api_profile_test.dart`
- After API route/version changes, re-run:
  - `flutter test test/data/api --reporter expanded`

## PR instructions
- Keep changes scoped to `memos_flutter_app` unless the task explicitly needs root docs/workflows/scripts.
- Follow current repository commit style (preferred): `feat: ...`, `fix: ...`, `chore: ...`.
- For release publishing, use a `v*` tag (for example `v1.0.16`); APK and Windows release workflows trigger from tags.
- Always run `flutter analyze` and `flutter test` before pushing.
- Before every commit, inspect the staged and unstaged changes for private, commercial, subscription, billing, entitlement, paywall, StoreKit, or other paid-feature code introduced into the public repository. If any is present, stop and alert the user instead of committing.

## Collaboration constraints
- Any change to API-related code requires explicit user approval before editing or committing. This includes request/response models, route adapters, version compatibility logic, and files under `memos_flutter_app/lib/data/api` and `memos_flutter_app/test/data/api`.
- Do not guess missing facts. If requirements, APIs, expected behavior, or reference details are unclear, ask the user for source material or clarification first. Never fabricate docs, endpoints, test results, or implementation details.
- To avoid encoding corruption, when writing Chinese text through PowerShell or other shell-based write commands, use Unicode escape sequences such as `\u4F60\u597D` instead of raw Chinese string literals. Prefer encoding-safe edit paths so Chinese content is not rewritten with mojibake.

## AI collaboration workflow
- For non-trivial or ambiguous work, use the local `openspec/` workflow before implementation.
- Load context from `openspec/project.md` before proposing architecture or touching multiple files.
- Start or update a change folder under `openspec/changes/<change-id>/` with `proposal.md`, `design.md`, `tasks.md`, and at least one delta spec before making broad code changes, unless the user explicitly asks to skip the workflow.
- Use `openspec/checklists/requirements.md` to clarify scope and `openspec/checklists/ai-review.md` to review AI-generated plans or patches.
- Prefer one approved task at a time. After each implementation step, report what changed, what was verified, and any remaining risks or assumptions.

## Modularity governance
- The canonical architecture phase is declared in `openspec/config.yaml` as `Architecture phase: <phase>`.
- The current baseline is `evolve_modularity` with a recorded modularity score of `4/10`. The project MUST remain in `evolve_modularity` until the score reaches at least `8/10` and every critical checklist item is satisfied.
- Critical checklist items:
  - `1.` No `state -> features` reverse dependencies.
  - `2.` No `application -> features` reverse dependencies.
  - `3.` No `core -> state|application|features` upward dependencies except explicitly approved adapters.
  - `4.` No reused shared domain logic hidden inside screen or widget files.
- Full quantified modularity checklist:
  - `1.` No `state -> features` reverse dependencies. Critical.
  - `2.` No `application -> features` reverse dependencies. Critical.
  - `3.` No `core -> state|application|features` upward dependencies except explicitly approved adapters. Critical.
  - `4.` No reused shared domain logic hidden inside screen or widget files. Critical.
  - `5.` `app.dart` and `main.dart` primarily act as composition roots.
  - `6.` Feature-to-feature collaboration prefers boundary/registry/provider seams over direct screen imports.
  - `7.` Touched write paths have clear owners such as services, repositories, or mutation seams.
  - `8.` Architecture guardrail tests protect the highest-risk dependency directions.
  - `9.` OpenSpec artifacts document the active architecture phase and expected modularity behavior.
  - `10.` Every change touching a coupled area leaves that area equal or better structured than before.
- When the phase is `evolve_modularity`:
  - Any bug fix, feature addition, or refactor that touches a coupled area MUST leave that touched area equal or better structured than before.
  - Each such change MUST include at least one of the following unless the touched area is demonstrably not part of the coupling hotspot:
    - remove or isolate a reverse dependency
    - extract shared logic into a more stable seam
    - move UI-specific logic or types out of lower layers
    - add or tighten a guardrail that prevents the touched coupling from getting worse
  - Prefer scoped seam extraction and guardrails over broad rewrites.
- When the phase is `preserve_modularity`:
  - New changes MUST preserve boundaries and MUST NOT introduce new `state -> features`, `application -> features`, or `core -> higher-layer` dependencies except explicitly approved adapters covered by tests.
  - Shared business or domain logic MUST NOT be reintroduced into screen or widget files.
  - Architecture guardrail allowlists MUST only shrink or remain stable unless the user explicitly approves a boundary exception and the spec/config/test layers are updated together.
- Any future phase transition MUST update `AGENTS.md`, `openspec/config.yaml`, `openspec/specs/modularity-governance/spec.md`, and the affected `memos_flutter_app/test/architecture/...` guardrails in the same change.

## Code writing rules after the public/private split
- Write new app runtime code under `memos_flutter_app` only. Do not add new runtime files under the repository root `lib/`.
- Treat the public repository as a standalone community build. Do not add subscription, billing, entitlement, receipt, paywall, StoreKit, or other commercial logic directly into public shell files.
- The public shell may depend only on the bundle/provider seam for private extensions:
  - `memos_flutter_app/lib/private_hooks/private_extension_bundle_provider.dart`
  - `memos_flutter_app/lib/private_hooks/private_extension_bundle.dart`
  - `memos_flutter_app/lib/module_boundary/settings_entry_contribution.dart`
- The only reserved Dart overlay seam for future private code is `memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart`. Do not spread private/commercial hooks into other public files.
- Keep these files free of commercial branching logic:
  - `memos_flutter_app/lib/app.dart`
  - `memos_flutter_app/lib/main.dart`
  - `memos_flutter_app/lib/features/settings/settings_screen.dart`
  - `memos_flutter_app/lib/features/home/main_home_page.dart`
  - `memos_flutter_app/lib/features/home/app_drawer.dart`
  - `memos_flutter_app/lib/state/settings/preferences_provider.dart`
  - `memos_flutter_app/lib/data/models/app_preferences.dart`
  - `memos_flutter_app/lib/state/system/session_provider.dart`
  - `memos_flutter_app/lib/data/models/account.dart`
- `settings_screen.dart` is only responsible for rendering extension entries returned by the bundle. It must not perform capability, subscription, premium, or iOS commercial runtime checks.
- `AccessDecision.source` is diagnostic/logging metadata only. Never use it for feature flags, UI visibility, routing, unlock decisions, or any other business logic.
- Donation entry and QR asset stay public. Donor acknowledgement stays public. Crown state has been removed and must not be reintroduced into shared preferences, session state, or account state.
- Do not add paid-feature state to shared public models or stores such as:
  - `AppPreferences`
  - session/account models
  - update config / donor config
  - general-purpose repositories used by the public app shell
- Future commercial iOS code belongs in a private repository or private overlay, not in this public repo. Public iOS shell work is allowed only when it does not include App Store commercial behavior.
- Before deleting legacy or duplicate files, verify more than imports. Confirm there are no `path:` dependencies, workflow references, build-script references, tool references, or runtime path reads pointing to those files.
- When adding guardrails or repo scans, prefer two levels:
  - strong blockers for high-confidence commercial leakage or secrets
  - weak warnings for ambiguous terms that need human review
- Do not use any MCP tools or Skills unless the user has explicitly approved it in the current conversation. If such approval has not been given, do not invoke, rely on, or reference MCPs or Skills for analysis, editing, generation, search, or validation.
