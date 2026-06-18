import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/tags.dart';
import 'package:memos_flutter_app/state/memos/memo_tag_autocomplete.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';

void main() {
  group('memo tag autocomplete', () {
    test('compatible policy detects inline body tag query', () {
      const value = TextEditingValue(
        text: 'See #work',
        selection: TextSelection.collapsed(offset: 9),
      );

      final query = detectActiveTagQuery(
        value,
        policy: TagRecognitionPolicy.memosCompatible,
      );

      expect(query, isNotNull);
      expect(query!.start, 4);
      expect(query.end, 9);
      expect(query.query, 'work');
    });

    test('ignores non-collapsed selection and invalid partial tags', () {
      const selected = TextEditingValue(
        text: 'See #work',
        selection: TextSelection(baseOffset: 5, extentOffset: 9),
      );
      const invalid = TextEditingValue(
        text: 'See #bad#tag',
        selection: TextSelection.collapsed(offset: 12),
      );

      expect(detectActiveTagQuery(selected), isNull);
      expect(detectActiveTagQuery(invalid), isNull);
    });

    test('strict policy ignores body prose tag query', () {
      const value = TextEditingValue(
        text: 'See #work',
        selection: TextSelection.collapsed(offset: 9),
      );

      expect(
        detectActiveTagQuery(
          value,
          policy: TagRecognitionPolicy.memoflowStrict,
        ),
        isNull,
      );
    });

    test('strict policy detects first and last tag-zone prefix queries', () {
      const firstLine = TextEditingValue(
        text: '#work',
        selection: TextSelection.collapsed(offset: 5),
      );
      const lastLine = TextEditingValue(
        text: 'Body text\n\n#life',
        selection: TextSelection.collapsed(offset: 16),
      );

      expect(
        detectActiveTagQuery(
          firstLine,
          policy: TagRecognitionPolicy.memoflowStrict,
        )?.query,
        'work',
      );
      expect(
        detectActiveTagQuery(
          lastLine,
          policy: TagRecognitionPolicy.memoflowStrict,
        )?.query,
        'life',
      );
    });

    test('custom policy controls autocomplete eligibility', () {
      const body = TextEditingValue(
        text: 'See #work',
        selection: TextSelection.collapsed(offset: 9),
      );
      final noInline = TagRecognitionPolicy.custom(
        const TagRecognitionCustomOptions(inlineBodyTags: false),
      );
      final inline = TagRecognitionPolicy.custom(
        const TagRecognitionCustomOptions(inlineBodyTags: true),
      );

      expect(detectActiveTagQuery(body, policy: noInline), isNull);
      expect(detectActiveTagQuery(body, policy: inline)?.query, 'work');
    });

    test(
      'ranks suggestions by match quality, pinned flag, count, and path',
      () {
        const tags = <TagStat>[
          TagStat(tag: 'personal', path: 'personal', count: 8),
          TagStat(tag: 'work', path: 'work', count: 3),
          TagStat(tag: 'world', path: 'world', count: 6),
          TagStat(tag: 'alpha', path: 'team/work', count: 20),
          TagStat(tag: 'work', path: 'archive/work', count: 1, pinned: true),
        ];

        final suggestions = buildTagSuggestions(tags, query: 'wo');

        expect(suggestions.map((tag) => tag.path).toList(), <String>[
          'archive/work',
          'team/work',
          'world',
          'work',
        ]);
      },
    );

    test('deduplicates paths and honors limit', () {
      const tags = <TagStat>[
        TagStat(tag: 'work', path: 'work', count: 1),
        TagStat(tag: 'work duplicate', path: 'work', count: 99),
        TagStat(tag: 'world', path: 'world', count: 2),
      ];

      final suggestions = buildTagSuggestions(tags, query: 'wo', limit: 1);

      expect(suggestions.map((tag) => tag.path).toList(), <String>['world']);
    });
  });
}
