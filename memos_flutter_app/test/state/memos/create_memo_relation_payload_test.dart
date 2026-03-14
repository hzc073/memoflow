import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/core/memo_relations.dart';

void main() {
  test(
    'prepareReferenceRelationPatch keeps empty patch for clearing relations',
    () {
      final patch = prepareReferenceRelationPatch(
        memoUid: 'memo-1',
        relations: const <Map<String, dynamic>>[],
      );

      expect(patch.shouldSync, isTrue);
      expect(patch.relations, isEmpty);
    },
  );

  test(
    'normalizeReferenceRelationPayloads normalizes aliases and de-duplicates',
    () {
      final normalized = normalizeReferenceRelationPayloads(
        memoUid: 'memo-1',
        relations: const <Map<String, dynamic>>[
          {
            'related_memo': {'name': 'memo-2'},
            'type': 'REFERENCE',
          },
          {
            'relatedMemo': {'name': 'memos/memo-2'},
            'type': 'REFERENCE',
          },
          {'relatedMemoId': 'memo-3', 'type': 'REFERENCE'},
          {
            'relatedMemo': {'name': 'memos/memo-1'},
            'type': 'REFERENCE',
          },
        ],
      );

      expect(
        normalized,
        equals(<Map<String, dynamic>>[
          {
            'relatedMemo': {'name': 'memos/memo-2'},
            'type': 'REFERENCE',
          },
          {
            'relatedMemo': {'name': 'memos/memo-3'},
            'type': 'REFERENCE',
          },
        ]),
      );
    },
  );
}
