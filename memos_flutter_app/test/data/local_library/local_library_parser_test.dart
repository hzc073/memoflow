import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/local_library/local_library_parser.dart';

void main() {
  group('parseLocalLibraryMarkdown tags', () {
    test('splits whitespace-separated hashtags in front matter', () {
      const raw = '''
---
uid: memo-1
created: 2025-10-20T10:00:00Z
updated: 2025-10-20T10:00:00Z
visibility: PRIVATE
pinned: false
state: NORMAL
tags: #habit #network #edit #home #draft
---

2025-10-20 progress note.
''';

      final parsed = parseLocalLibraryMarkdown(raw);

      expect(
        parsed.tags,
        unorderedEquals(['habit', 'network', 'edit', 'home', 'draft']),
      );
    });

    test('does not keep the whole tags line as one tag', () {
      const raw = '''
---
uid: memo-2
created: 2025-10-20T10:00:00Z
updated: 2025-10-20T10:00:00Z
visibility: PRIVATE
pinned: false
state: NORMAL
tags: #habit #network #edit #home #draft
---

content
''';

      final parsed = parseLocalLibraryMarkdown(raw);

      expect(parsed.tags, isNot(contains('habit #network #edit #home #draft')));
    });
  });
}
