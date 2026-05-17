## Why

The current server settings page can keep showing one account's backend limits after the user switches to another account or workspace, because the state is not scoped to the active remote identity. That is a correctness issue: a stale snapshot can lead the UI to edit or save against the wrong server context.

## What Changes

- Bind server settings state to the active account or local-library identity so the snapshot is rebuilt when the workspace context changes.
- Reset or reload the server settings screen when the active remote identity changes, instead of reusing a previous account's data.
- Keep save actions routed through the current server API only, so the displayed values and the write target stay aligned.
- Add focused tests for account/workspace switching, stale snapshot avoidance, and save-target correctness.

## Capabilities

### New Capabilities
- `server-settings-account-scope`: server settings state MUST be keyed to the current active account or local-library identity, and MUST not leak a previous account's snapshot into a different server context.

### Modified Capabilities
- None

## Impact

- Affected Flutter areas:
  - `memos_flutter_app/lib/state/settings/server_settings_provider.dart`
  - `memos_flutter_app/lib/features/settings/server_settings_screen.dart`
  - `memos_flutter_app/lib/state/system/session_provider.dart`
  - `memos_flutter_app/lib/state/system/local_library_provider.dart`
  - settings widget/state tests under `memos_flutter_app/test/features/settings/`
- Affected behavior:
  - Server settings read state must refresh when account/workspace identity changes.
  - Save operations must use the current API context, not a stale provider snapshot.
- Modularity note:
  - Active architecture phase: `evolve_modularity`.
  - This change touches checklist items 4 and 7 by keeping shared server-setting logic in the state/data boundary and giving the write path a single clear owner.
