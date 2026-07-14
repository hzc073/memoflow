# AGENTS.md

## Repository role
- This is the public community edition of MemoFlow. It contains Android, Windows, Linux, Web, and platform-neutral Flutter functionality.
- The public repository is not a source for Apple-specific, commercial, private-extension, signing, or App Store functionality.
- During public-repository migration, keep inherited Apple files exactly as they exist in the ancestor repository. Do not use this repository to synchronize private Apple work.

## Development environment
- The app root is `memos_flutter_app`; run Flutter commands from that directory.
- Match the CI toolchain when possible: Flutter `3.41.9` (stable) with its bundled Dart SDK, compatible with `^3.10.4` in `pubspec.yaml`.
- First-time setup:
  - `cd memos_flutter_app`
  - `flutter pub get`
- Supported local build scripts:
  - Android APK: `pwsh .\tool\build_apk.ps1`
  - Windows bundle and installer: `pwsh .\tool\build_windows.ps1`
- If Windows desktop files are missing, run `flutter create --platforms=windows .` from `memos_flutter_app`.

## Testing and public-repository checks
- CI API compatibility tests:
  - `flutter test test/data/api --reporter expanded`
- CI architecture checks:
  - `flutter analyze`
  - `flutter test test/architecture --reporter expanded`
- Before a user-authorized push or PR, run from `memos_flutter_app`:
  - `flutter analyze`
  - `flutter test`
- For focused API debugging:
  - `flutter test test/data/api/server_api_profile_test.dart`
- After API route or version changes, rerun:
  - `flutter test test/data/api --reporter expanded`
- Before a public-export commit, also run from the repository root:
  - `pwsh .github/scripts/public_repo_guardrails.ps1`

## Public migration: Apple content isolation
- Never stage or commit changes under `memos_flutter_app/ios/**` or `memos_flutter_app/macos/**`.
- Never migrate, modify, or delete Apple-only build, signing, store, privacy-permission, Xcode, Fastlane, iOS/macOS CI, or iOS/macOS release-script content.
- Public Dart code must not introduce iOS/macOS-only platform branches, StoreKit, App Store, iCloud, Apple Pay, or settings entries that serve only Apple platforms.
- When a source file mixes public behavior with Apple-only behavior, retain only the safely separable public behavior. If safe separation is not clear, do not stage that file; ask the user to decide.
- Do not use `git add .` or `git add -A`. Stage only explicit public file paths, or use `git add -p` when staging an approved public-only hunk.
- Before every commit, run and inspect both commands:
  - `git diff --cached --name-only`
  - `git diff --cached`
- Confirm that the staged set contains only Android, Windows, Linux, Web, or platform-neutral Flutter functionality.
- Do not push, create a PR, or modify the ancestor repository's `main` branch without explicit user confirmation.

## Public code boundaries
- Write new app runtime code only under `memos_flutter_app`. Do not add runtime files under the repository-root `lib/` directory.
- Do not introduce subscription, billing, entitlement, receipt, paywall, StoreKit, purchase, or private commercial logic into public source code.
- The reserved `memos_flutter_app/lib/private_hooks/` seam must remain inert in the public repository. Do not add files there or activate extension entries or access decisions for private behavior.
- Keep commercial state out of shared models and stores, including `AppPreferences`, session/account models, update or donor configuration, and general-purpose public repositories.
- `AccessDecision.source` is diagnostic metadata only. Never use it for feature flags, visibility, routing, unlock decisions, or other business logic.
- Before deleting legacy or duplicate files, check imports, `path:` dependencies, workflow references, build scripts, tools, and runtime path reads.
- Public guardrails should use strong blockers for high-confidence secrets or commercial leakage and weak warnings for ambiguous terms requiring human review.

## Collaboration constraints
- Any API-related change requires explicit user approval before editing or committing. This includes request/response models, route adapters, version compatibility logic, and files under `memos_flutter_app/lib/data/api` and `memos_flutter_app/test/data/api`.
- Do not guess missing facts. When requirements, APIs, expected behavior, or reference material are unclear, request clarification instead of fabricating a solution or test result.
- Use encoding-safe edit paths. When PowerShell must write Chinese text, use Unicode escape sequences rather than raw Chinese string literals.

## AI collaboration workflow
- For non-trivial or ambiguous work, use the local `openspec/` workflow before implementation.
- Load `openspec/project.md` before proposing architecture or touching multiple files.
- OpenSpec proposals, designs, tasks, delta specs, implementation notes, and archive summaries default to Simplified Chinese unless the user requests another language. Preserve structural keywords, normative requirement words, identifiers, paths, API names, and commands in English.
- Before broad code changes, create or update `openspec/changes/<change-id>/` with `proposal.md`, `design.md`, `tasks.md`, and at least one delta spec, unless the user explicitly asks to skip the workflow.
- Use `openspec/checklists/requirements.md` to clarify scope and `openspec/checklists/ai-review.md` to review AI-generated plans or patches.
- Prefer one user-approved task at a time. After each implementation step, report the change, verification, and any remaining risk or assumption.

## Modularity governance
- The canonical architecture phase is declared in `openspec/config.yaml` as `Architecture phase: <phase>`.
- The current phase is `evolve_modularity` with a recorded modularity score of `10/10`. The preserve-phase gate is satisfied, but the phase remains unchanged until a dedicated phase-transition change updates all required governance layers together.
- Critical boundaries:
  - No `state -> features` reverse dependencies.
  - No `application -> features` reverse dependencies.
  - No `core -> state|application|features` upward dependencies except explicitly approved adapters.
  - Do not hide reusable shared domain logic inside screens or widgets.
- While the phase is `evolve_modularity`, a change touching a coupling hotspot must leave that area equal or better structured by removing or isolating a reverse dependency, extracting a stable shared seam, moving UI-specific logic or types out of lower layers, or strengthening a guardrail.
- Prefer scoped seam extraction and guardrails over broad rewrites.
- A future phase transition must update `AGENTS.md`, `openspec/config.yaml`, `openspec/specs/modularity-governance/spec.md`, and the affected `memos_flutter_app/test/architecture/...` guardrails in the same change.

## Commit and release discipline
- Keep changes scoped to `memos_flutter_app` unless the task explicitly requires root documentation, workflows, or scripts.
- Follow the existing commit style: `feat: ...`, `fix: ...`, or `chore: ...`.
- Use a `v*` tag for authorized releases; Android APK and Windows release workflows trigger from tags.
- Before every commit, inspect staged and unstaged changes for secrets, certificates, tokens, signing material, local credentials, unintended release artifacts, Apple-only content, and private or commercial code.
- Do not treat a successful build as authorization to stage excluded files or to push. Staging, pushing, PR creation, and ancestor-branch changes require the user authority stated above.
