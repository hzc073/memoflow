## extractTags call-site classification

Persistence-producing create/edit paths:

- `lib/state/memos/note_input_controller.dart`
- `lib/state/memos/memo_mutation_service.dart`
- `lib/state/memos/memo_timeline_provider.dart`
- `lib/features/memos/memo_editor_screen.dart`
- `lib/features/memos/memo_detail_screen.dart`
- `lib/features/memos/memos_list_inline_compose_coordinator.dart`
- `lib/features/memos/memos_list_mutation_coordinator.dart`
- `lib/application/quick_input/quick_input_service.dart`
- `lib/features/share/share_quick_clip_service.dart`

Import/sync paths that eventually persist memo tags:

- `lib/state/memos/memos_remote_sync_state_sync.part.dart`
- `lib/state/memos/memos_remote_sync_attachments.part.dart`
- `lib/application/sync/local_library_scan_service.dart`
- `lib/state/memos/flomo_import_controller.dart`
- `lib/state/memos/swashbuckler_diary_import_controller.dart`

Search/display-only fallback paths:

- `lib/state/memos/memos_search_providers.part.dart`
- `lib/data/ai/ai_semantic_memo_search_service.dart`
- `lib/features/desktop/quick_input/desktop_quick_input_window.dart`
- `lib/features/review/daily_review_screen.dart`
- `lib/features/review/ai_summary_screen.dart`

Implementation note: call sites may keep using `extractTags` to derive raw candidate paths, but persistence writes should converge on the shared reconciliation seam owned below feature UI.

## Maintenance rebuild policy

`AppDatabase.rebuildMemoTagsFromContent()` is an explicit maintenance operation, not an automatic upgrade migration. It walks stored memos incrementally, recomputes candidate tags from current memo content with `extractTags`, reconciles them through `MemoTagReconciler`, and updates `memo_tags`, `memos.tags`, FTS tag data, and tag statistics together via the existing write/update seams.

This keeps historical cleanup available for false positives such as code-context `#include` while avoiding silent policy loss for users who may have stored tags that are not present in memo content.
