## Why

Memo search currently behaves like token-prefix search in some flows, so a note whose content contains a continuous CJK phrase can be found from the beginning of the token but not from a middle substring. This surprises users because the visible search box implies that any continuous text fragment in a memo should be discoverable.

The issue is most visible for Chinese content, but the broader problem is inconsistent search semantics across local cache search, remote search, shortcut/quick-search flows, and link-memo lookup.

## What Changes

- Define a unified memo search contract: a plain text query should match any continuous substring in memo content, not only token prefixes.
- Apply the same expected behavior across main memo search, local/offline search, quick search, shortcut search, and link-memo search.
- Preserve existing filters for state, tags, creator scope, date ranges, advanced filters, and shortcut predicates.
- Keep remote search compatibility with different Memos server versions, but normalize final app-visible results when server search semantics differ.
- Add focused coverage for CJK substring cases and mixed local/remote search paths.

## Capabilities

### New Capabilities
- `memo-search`: Defines user-visible memo search semantics and consistency requirements across local and remote search surfaces.

### Modified Capabilities
- None.

## Impact

- Local database search in `memos_flutter_app/lib/data/db/app_database.dart`.
- Memo search providers in `memos_flutter_app/lib/state/memos/memos_search_providers.part.dart`.
- Link-memo lookup in `memos_flutter_app/lib/state/memos/link_memo_controller.dart`.
- Memo list query routing in `memos_flutter_app/lib/features/memos/memos_list_screen_view_state.dart` if implementation needs source selection changes.
- API compatibility behavior in `memos_flutter_app/lib/data/api` may need review if remote search fallback behavior changes.
- Tests should cover local DB search, provider-level filtering behavior, and API-version-sensitive remote search behavior where applicable.
