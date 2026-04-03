import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/memo_relations.dart';

void main() {
  group('resolveMemoRelationsSidecarSnapshot', () {
    test('marks missing cache with positive count as incomplete', () {
      final snapshot = resolveMemoRelationsSidecarSnapshot(
        relationCount: 2,
        relationsJson: null,
      );

      expect(snapshot.relationCount, 2);
      expect(snapshot.relations, isEmpty);
      expect(snapshot.relationsComplete, isFalse);
    });

    test('marks zero-count missing cache as complete empty metadata', () {
      final snapshot = resolveMemoRelationsSidecarSnapshot(
        relationCount: 0,
        relationsJson: null,
      );

      expect(snapshot.relationCount, 0);
      expect(snapshot.relations, isEmpty);
      expect(snapshot.relationsComplete, isTrue);
    });

    test('keeps decoded relations when cache is available', () {
      final snapshot = resolveMemoRelationsSidecarSnapshot(
        relationCount: 1,
        relationsJson:
            '[{"memo":{"name":"memos/memo-1","snippet":"memo one"},"relatedMemo":{"name":"memos/memo-2","snippet":"memo two"},"type":"REFERENCE"}]',
      );

      expect(snapshot.relationCount, 1);
      expect(snapshot.relationsComplete, isTrue);
      expect(snapshot.relations, hasLength(1));
      expect(snapshot.relations.single.memo.snippet, 'memo one');
    });
  });
}
