## 1. Local Tool Structure

- [x] 1.1 Create `F:/Homework/memoflow_config/config/` with `server.py`, `manager.html`, `manager.js`, and `manager.css`.
- [x] 1.2 Implement `server.py` startup so it resolves the repository root, binds to `127.0.0.1`, serves static manager files, and prints the local URL.
- [x] 1.3 Add fixed API routing for config load/save, validate, build, preview summary, and asset operations without exposing arbitrary shell execution.
- [x] 1.4 Add path-resolution helpers that reject traversal and limit writes to `update/manifest.json`, `update/announcements/*.json`, `update/donors.json`, `update/assets/*`, and generated build output.

## 2. Config Data Service

- [x] 2.1 Implement JSON read/write helpers using UTF-8, structured `json` parsing, stable indentation, and atomic replace writes.
- [x] 2.2 Implement config load aggregation for `manifest.json`, `donors.json`, announcement files referenced by `manifest.announcement_ids`, and current generated output metadata when present.
- [x] 2.3 Implement update announcement save support for editing the current `latest_announcement_id` announcement file.
- [x] 2.4 Implement new update announcement creation with numeric-string id generation, announcement file creation, `announcement_ids`, `latest_announcement_id`, and optional `announcement_tag_index` updates.
- [x] 2.5 Implement historical announcement read support sorted consistently with the existing numeric id release-note ordering.

## 3. V3 and Legacy Compatibility

- [x] 3.1 Implement CRUD operations for `manifest.notices[]` with status, schedule, audience, display policy, localized title/body, severity, priority, and revision fields.
- [x] 3.2 Implement explicit selected-notice sync to legacy `manifest.notice` and `manifest.notice_enabled`.
- [x] 3.3 Implement safe legacy notice disable/clear behavior that is visible in the UI.
- [x] 3.4 Implement CRUD operations for `manifest.updates[]` with platform, channel, version, force, URL, release note id, schedule, audience, status, and priority fields.
- [x] 3.5 Implement explicit primary-update sync from a selected v3 update candidate to `manifest.version_info.<platform>` for old app compatibility.

## 4. Donor and Asset Management

- [x] 4.1 Implement donor list add/edit/delete operations backed by `update/donors.json`.
- [x] 4.2 Add reference detection for `new_donor_ids` across announcement files before donor deletion.
- [x] 4.3 Add avatar URL editing and optional local asset copy/upload into `update/assets/` with safe filename handling.
- [x] 4.4 Render donor previews from saved donor data and avatar references.

## 5. Browser UI

- [x] 5.1 Build manager layout with sections for current update announcement, history, notification notices, update candidates, donors, validation/build output, and raw JSON diagnostics.
- [x] 5.2 Add forms for current update announcement summary lines and grouped release note items in Chinese and English.
- [x] 5.3 Add read-first historical update announcement view with an explicit edit action.
- [x] 5.4 Add v3 notice editor with local notice preview and legacy-sync controls.
- [x] 5.5 Add v3 update candidate editor with update summary preview and legacy version-info sync controls.
- [x] 5.6 Add donor management UI with deletion warnings when donor ids are referenced by announcements.
- [x] 5.7 Add client-side dirty-state handling so unsaved changes are visible before loading another record or running build.

## 6. Validation and Build Integration

- [x] 6.1 Wire the validate action to `python .github/scripts/build_update_config.py --root update --validate-only` and surface stdout/stderr in the UI.
- [x] 6.2 Wire the build action to `python .github/scripts/build_update_config.py --root update --output dist/update/latest.json` and surface the generated path.
- [x] 6.3 Add v3 production-safety validation for duplicate ids, draft production items, schedule bounds, missing public notice body, invalid forced update URLs, unresolved release note links, Play-channel APK warnings, missing English content, long expiry windows, and suspicious test/debug wording.
- [x] 6.4 Ensure validation runs after save operations that modify `manifest.notices[]`, `manifest.updates[]`, announcement indexes, or donor references.

## 7. Documentation and Launch

- [x] 7.1 Add a short usage section in `F:/Homework/memoflow_config/README.md` or `config/README.md` explaining how to start the local manager and what files it edits.
- [x] 7.2 Document that `dist/update/latest.json` is generated output and Git sync remains a manual step after validation/build.
- [x] 7.3 Include rollback guidance for disabling a v3 notice, clearing legacy notice, restoring previous source JSON, and rebuilding.

## 8. Verification

- [x] 8.1 Run the existing split-config validation command from `F:/Homework/memoflow_config`.
- [x] 8.2 Run the existing build command and inspect that generated `dist/update/latest.json` contains legacy fields plus v3 arrays when authored.
- [x] 8.3 Smoke test the local manager by loading config, editing a throwaway draft/preview notice, previewing it, saving, validating, and reverting the test data.
- [x] 8.4 Smoke test donor reference warning by attempting to delete a referenced donor without finalizing the deletion.
- [x] 8.5 Confirm implementation did not add new files under `memos_flutter_app/lib` and did not introduce new app runtime reverse dependencies.
- [x] 8.6 Run `openspec status --change "add-local-config-manager"` and confirm the change is apply-ready after tasks remain tracked.
