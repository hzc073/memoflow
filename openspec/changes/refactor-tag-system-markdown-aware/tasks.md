## 1. Scope And Rules

- [x] 1.1 Confirm the first implementation slice: Markdown-aware extraction plus shared reconciliation seam, without tag UI redesign
- [x] 1.2 Confirm no API-related files under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api` are in scope
- [x] 1.3 Re-check reference behavior from `F:\Homework\memos\参考项目\memos-0.28.0` for Markdown tag contexts before implementation

## 2. Markdown-Aware Extraction

- [x] 2.1 Add `core/tags.dart` tests proving fenced code blocks do not produce tags, including `#include`
- [x] 2.2 Add tests proving inline code spans do not produce tags
- [x] 2.3 Add tests proving Markdown links and URL fragments remain protected
- [x] 2.4 Add tests proving real tags in prose, lists, blockquotes, tables, and allowed headings still extract
- [x] 2.5 Update `extractTags` or a new shared extractor to walk Markdown-aware content rather than raw lines

## 3. Shared Tag Reconciliation

- [x] 3.1 Identify all current `extractTags(` call sites and classify create/edit/import/sync/search/display usage
- [x] 3.2 Introduce a shared tag reconciliation seam that returns canonical tag paths and resolved tag ids for memo writes
- [x] 3.3 Migrate memo create/edit write paths to the shared seam
- [x] 3.4 Migrate import/sync paths that persist memo tags to the shared seam where appropriate
- [x] 3.5 Keep UI-only suggestion/display paths consuming shared helpers without taking ownership of persistence reconciliation

## 4. Persistence Consistency

- [x] 4.1 Add focused DB tests proving `memo_tags` and `memos.tags` agree after memo creation
- [x] 4.2 Add focused DB tests proving tag edit/move/delete keeps `memo_tags`, `memos.tags`, search, and stats consistent
- [x] 4.3 Add search/stat tests proving false tags from code contexts do not appear in tag stats or tag search data

## 5. Maintenance Rebuild

- [x] 5.1 Design an explicit incremental operation to recompute stored memo tags from current content and extractor rules
- [x] 5.2 Add tests proving rebuild removes code-context false positives and preserves real tags
- [x] 5.3 Decide whether rebuild is user-triggered, upgrade-triggered, or deferred to a later change

## 6. Modularity Guardrails

- [x] 6.1 Verify shared tag grammar remains out of feature screens/widgets
- [x] 6.2 Add or tighten architecture guardrail coverage if a new `TagReconciler` seam is introduced
- [x] 6.3 Verify no new `state -> features`, `application -> features`, or `core -> higher-layer` imports are introduced

## 7. Validation

- [x] 7.1 Run focused tag tests from `memos_flutter_app`
- [x] 7.2 Run focused memo write/tag persistence tests from `memos_flutter_app`
- [x] 7.3 Run `flutter analyze`
- [x] 7.4 Run `flutter test`

