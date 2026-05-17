## 1. Persistence Extraction

- [x] 1.1 Identify all current `compose_drafts` schema, read-query, and local-write SQL in `AppDatabase` and `AppDatabaseWriteDao`, including edit-draft columns and partial unique index behavior.
- [x] 1.2 Add focused compose draft persistence file(s) under `memos_flutter_app/lib/data/db/` for table creation, idempotent column/index ensure logic, read queries, and local row writes.
- [x] 1.3 Move `compose_drafts` schema SQL and edit-draft ensure helpers into the new persistence owner while preserving `onCreate`, `onUpgrade`, and `onOpen` ordering.
- [x] 1.4 Move compose draft read queries into the new persistence owner while keeping returned row maps and ordering unchanged.
- [x] 1.5 Move compose draft local write SQL into the new persistence owner while preserving transaction semantics for `replaceComposeDraftRows`.

## 2. Facade And Write Proxy Preservation

- [x] 2.1 Keep existing `AppDatabase` compose draft public methods as facade methods that delegate to the extracted persistence owner.
- [x] 2.2 Preserve desktop write proxy dispatch for `upsertComposeDraftRow`, `replaceComposeDraftRows`, `deleteComposeDraft`, and `deleteComposeDraftsByWorkspace`.
- [x] 2.3 Preserve `AppDatabaseWriteDao` notification behavior after compose draft writes.
- [x] 2.4 Confirm `ComposeDraftRepository` and `ComposeDraftMutationService` continue to own state-layer draft persistence decisions without direct feature-widget DB writes.

## 3. Guardrails

- [x] 3.1 Add or tighten an architecture guardrail proving compose draft persistence files under `lib/data/db/` do not import `features/`, `state/`, or `application/`.
- [x] 3.2 Add or tighten a guardrail that fails if feature widgets directly call low-level compose draft DB write methods.
- [x] 3.3 Verify existing architecture allowlists are not expanded for `state -> features`, `application -> features`, `core -> higher-layer`, direct `AppDatabase` writes, or `AppDatabaseWriteDao` construction.

## 4. Focused Behavior Verification

- [x] 4.1 Run compose draft repository tests covering create draft compatibility, edit draft upsert uniqueness, edit draft lookup/delete, and attachment serialization.
- [x] 4.2 Run compose draft transfer and WebDAV backup tests covering draft row round-trip behavior.
- [x] 4.3 Run focused Draft Box and note input tests that restore, save, delete, and refresh compose drafts.
- [x] 4.4 Run DB write envelope and migration-focused tests that cover compose draft write proxy and schema helper behavior.

## 5. Final Verification

- [x] 5.1 Run `flutter test test/architecture` from `memos_flutter_app`.
- [x] 5.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 5.3 Run `flutter test` from `memos_flutter_app`.
- [x] 5.4 Review the final diff to confirm `AppDatabase` shrank in compose draft responsibility without behavior, schema, or API route changes.
