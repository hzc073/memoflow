## 1. OPML Parser and Exporter

- [ ] 1.1 Add OPML parser service for common RSS outline attributes.
- [ ] 1.2 Add OPML export service for RSS feed subscriptions and collection/folder organization.
- [ ] 1.3 Add URL normalization and duplicate classification helpers.
- [ ] 1.4 Keep parser/exporter logic outside widgets and independent from Memos server API code.

## 2. Import Preview

- [ ] 2.1 Add import preview model for new feeds, duplicates, invalid entries, folders, and commit actions.
- [ ] 2.2 Add OPML file selection and preview flow.
- [ ] 2.3 Show what will be added, skipped, attached to a collection, or unresolved before commit.
- [ ] 2.4 Require confirmation before creating collections from OPML folders.

## 3. Import Commit

- [ ] 3.1 Commit selected new feeds through RSS subscription repository seams.
- [ ] 3.2 Attach existing duplicate feeds to the chosen collection when requested.
- [ ] 3.3 Skip malformed or unsupported entries without failing the entire import.
- [ ] 3.4 Ensure OPML import does not create RSS articles or memos.

## 4. Export Flow

- [ ] 4.1 Export RSS subscriptions from selected collection or all collections.
- [ ] 4.2 Preserve collection/folder organization in OPML where practical.
- [ ] 4.3 Exclude RSS article bodies, read state, saved memo links, memo content, and memo metadata.
- [ ] 4.4 Add file save/share behavior using existing platform-safe file utilities.

## 5. Tests and Guardrails

- [ ] 5.1 Add parser tests for common OPML files, nested folders, missing title/text, and malformed XML.
- [ ] 5.2 Add import preview tests for duplicates, invalid entries, and folder mapping.
- [ ] 5.3 Add commit tests that import attaches feeds without creating memos or RSS articles.
- [ ] 5.4 Add exporter tests for collection grouping and round-trip subscription metadata.
- [ ] 5.5 Add or tighten guardrails so OPML parser/exporter services do not depend on feature UI or Memos API files.

## 6. Verification

- [ ] 6.1 Run `dart format` on changed Dart files in `memos_flutter_app`.
- [ ] 6.2 Run focused OPML parser/exporter/import tests.
- [ ] 6.3 Run relevant architecture guardrail tests.
- [ ] 6.4 Run `flutter analyze` from `memos_flutter_app`.
- [ ] 6.5 Run `flutter test` from `memos_flutter_app`.
