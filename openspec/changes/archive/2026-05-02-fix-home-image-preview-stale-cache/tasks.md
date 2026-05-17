## 1. Cache Freshness Seam

- [x] 1.1 Add a feature-level helper for memo media attachment source fingerprint/cache key logic.
- [x] 1.2 Include attachment `name`, `filename`, `type`, `size`, `externalLink`, `width`, `height`, and `hash` in the fingerprint.
- [x] 1.3 Refactor `MemosListMemoCardContainer` cache key construction to use the helper without adding lower-layer reverse dependencies.

## 2. Home Preview Behavior

- [x] 2.1 Verify home/list media entries are rebuilt when only attachment source metadata changes.
- [x] 2.2 Confirm `MemoMediaGrid` / `MemoImageGrid` tap flow receives updated `ImagePreviewItem.localFile` after LocalSync-style attachment migration.
- [x] 2.3 Keep detail page and image preview gallery rendering behavior unchanged while fixing the stale home/list source.

## 3. Clip Inline Source Migration

- [x] 3.1 Identify the safest seam for replacing share-inline local URLs during `LocalSyncController._handleUploadAttachment`.
- [x] 3.2 When an upload payload has `share_inline_image` and `share_inline_local_url`, replace matching memo content URLs with `Uri.file(privatePath).toString()` before deleting the managed upload source.
- [x] 3.3 Reuse or extend share inline URL variant matching so HTML attributes, escaped URLs, and markdown image forms are handled consistently.
- [x] 3.4 Ensure attachment metadata `externalLink` and matching memo content inline image URL point to the same private local file after LocalSync finalization.

## 4. Regression Tests

- [x] 4.1 Add helper tests proving the fingerprint changes for preview-relevant attachment metadata changes.
- [x] 4.2 Add a home/list memo card regression test for stale queued path replaced by private attachment path with unchanged `updateTime` and attachment count.
- [x] 4.3 Add or update widget assertions to prove preview opening no longer references the deleted queued upload source.
- [x] 4.4 Add LocalSync/state regression coverage for `share_inline_image` upload finalization rewriting memo content from queued URL to private attachment URL.
- [x] 4.5 Add share inline URL rewrite tests for HTML `<img src>`, markdown image syntax, and escaped URL variants if existing helpers are extended.

## 5. Verification

- [x] 5.1 Run focused Flutter tests covering memo media cache/source freshness.
- [x] 5.2 Run focused LocalSync/share inline tests covering queued-to-private inline URL migration.
- [x] 5.3 Run `flutter test test/features/memos` from `memos_flutter_app` if focused tests pass. Attempted twice; directory run timed out, and isolated `_tmp_note_harness_smoke_test.dart` has an existing compile error for `AppDatabase.database`.
- [x] 5.4 Review touched imports to confirm no new `state -> features`, `application -> features`, or `core -> features` dependency is introduced beyond already-approved seams.
