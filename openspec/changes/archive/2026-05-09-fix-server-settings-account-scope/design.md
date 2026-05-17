## Context

`serverSettingsProvider` currently owns a `ServerSettingsState` snapshot, but it does not watch the active account or local-library identity. It calls `load()` once when the provider is created, then later save methods call `ref.read(memosApiProvider)`.

That creates an identity drift:

```text
Before

Account A opens ServerSettingsScreen
  -> serverSettingsProvider loads snapshot A

User switches to Account B
  -> serverSettingsProvider remains alive
  -> UI may still show snapshot A
  -> save reads memosApiProvider now pointing at B
```

The dependency direction is already acceptable: `features/settings -> state/settings -> data/api`. The problem is not a reverse dependency; it is that the state owner is not scoped to the same identity as its API write path. This change keeps the dependency direction the same while tightening the provider boundary.

Active architecture phase: `evolve_modularity`. The touched modularity items are:

- Checklist item 4: shared server-setting state ownership must stay out of widgets.
- Checklist item 7: server-setting writes need one clear state/data owner and must not be split between stale UI state and current API reads.

## Goals / Non-Goals

**Goals:**

- Rebuild or reload server settings state whenever the active remote API context changes.
- Ensure displayed values and save operations use the same active account identity.
- Ensure local-library mode does not send server settings API requests.
- Add regression coverage for account switching and save-target correctness.
- Preserve the existing dependency direction `features -> state -> data`.

**Non-Goals:**

- Do not change Memos server settings route compatibility or request/response parsing.
- Do not add new backend APIs, role detection, or account model fields.
- Do not broaden this into arbitrary instance setting management.
- Do not move version routing, parsing, or permission classification into `ServerSettingsScreen`.

## Decisions

### Decision 1: Make `serverSettingsProvider` identity-aware

The provider should watch the active local-library state and the active remote API context. When those dependencies change, Riverpod should create a fresh controller and dispose the old one.

Recommended shape:

```text
serverSettingsProvider
  watches currentLocalLibraryProvider
  watches appSessionProvider / memosApiProvider for current remote API context
  creates ServerSettingsController(api, mode)
```

`autoDispose` should be added as a useful cleanup layer, but it is not sufficient by itself. `autoDispose` fixes stale state after the page is closed; it does not reliably fix identity changes while a settings page or desktop settings pane remains mounted.

Alternative considered: only call `refresh()` from `ServerSettingsScreen` when it builds. This was rejected because it leaves scoping rules in the widget and does not protect save methods from reading a different API than the loaded snapshot.

Alternative considered: use a `StateNotifierProvider.family` keyed by an explicit scope object. This is valid, but it adds more UI/provider plumbing than needed if the provider factory can watch the same identity inputs directly.

### Decision 2: Inject the active API into the controller

`ServerSettingsController` should receive the active `MemosApi?` or equivalent remote context at construction time. `load()` and save methods should use that injected API, not call `ref.read(memosApiProvider)` at mutation time.

This makes the controller internally consistent:

```text
After

Account B provider instance
  -> snapshot loaded from B API
  -> save uses B API
```

For local-library mode or no remote account, the controller can load an unavailable `ServerSettingsSnapshot.localLibrary()` and skip API requests.

Alternative considered: keep reading `memosApiProvider` inside each save method. This was rejected because it is exactly how snapshot identity and write identity can diverge.

### Decision 3: Rely on provider disposal to ignore stale async completions

When the active account changes during a load, the old provider instance should be disposed. Existing `mounted` checks in `ServerSettingsController` already prevent late async completions from writing state after disposal. The implementation should keep that guard.

If a save request was already sent before the user switched accounts, the request may still complete against the old server. The important guarantee is that the old completion must not revive stale UI state after the provider scope changes.

### Decision 4: Add a real lifecycle regression test

The regression test should exercise the actual provider lifecycle, not only a provider override with a fake controller. A useful test shape is:

```text
Fake server A returns memo limit 2048
Fake server B returns memo limit 4096

start with account A
  -> screen shows 2048

switch current account to B while provider/screen remains alive
  -> screen reloads
  -> screen shows 4096

save a value
  -> B server receives PATCH
  -> A server receives no new save
```

The test can live in an existing tracked settings test file to avoid ignored-path churn. It can use small local fake HTTP servers and the real `memosApiProvider`, or a carefully scoped provider override that still changes identity and rebuilds the provider.

## Risks / Trade-offs

- [Risk] `autoDispose` and identity watching can cause the settings page to reload more often. -> Mitigation: server settings is not a high-frequency surface, and correctness is more important than caching stale administrative values.
- [Risk] Changing the controller constructor can break existing tests that subclass or override `ServerSettingsController`. -> Mitigation: update those test fakes to pass the new constructor inputs or override methods cleanly.
- [Risk] Account switching during an in-flight save cannot fully cancel the already-sent HTTP request. -> Mitigation: dispose the old controller and ignore its completion; require new saves after the switch to use the new account context.
- [Risk] A no-account state and local-library mode currently share the same unavailable snapshot. -> Mitigation: keep that behavior unless implementation reveals a concrete UI copy need; avoid adding model churn for this narrow bug fix.

## Migration Plan

No data migration is required.

Implementation order:

1. Update `serverSettingsProvider` to watch the active identity and construct a scoped controller.
2. Update `ServerSettingsController` to use the injected API/context for load and save operations.
3. Keep attachment upload limit resolver invalidation after successful attachment limit saves.
4. Add regression tests for account switching and current-account save target.
5. Run focused settings tests, then `flutter analyze` and `flutter test`.

Rollback is straightforward: revert the provider/controller scoping change and the new regression tests. No persistent data or backend schema is affected.

## Open Questions

- None currently. The expected fix is local to provider/controller state ownership and tests.
