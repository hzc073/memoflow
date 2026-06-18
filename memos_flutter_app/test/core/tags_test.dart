import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/tags.dart';

void main() {
  test('normalizeTagPath preserves tag case', () {
    expect(normalizeTagPath('  #Work / Sub  '), 'Work/Sub');
    expect(normalizeTagPath('#work/Sub'), 'work/Sub');
  });

  test('extractTags preserves tag case and distinguishes variants', () {
    expect(extractTags('#Work #work'), const <String>['Work', 'work']);
  });

  test('extractTags preserves v0.27 backend-compatible characters', () {
    const eyeTag = 'watch\u{1F441}\uFE0F';
    const familyTag =
        'family\u{1F468}\u200D\u{1F469}\u200D\u{1F467}\u200D\u{1F466}';

    expect(
      extractTags('#science&tech #$eyeTag #$familyTag #work/project-2026'),
      const <String>[
        'family\u{1F468}\u200D\u{1F469}\u200D\u{1F467}\u200D\u{1F466}',
        'science&tech',
        'watch\u{1F441}\uFE0F',
        'work/project-2026',
      ],
    );
  });

  test('normalizeTagPath preserves v0.27 backend-compatible characters', () {
    expect(normalizeTagPath('#science&tech'), 'science&tech');
    expect(normalizeTagPath('#watch\u{1F441}\uFE0F'), 'watch\u{1F441}\uFE0F');
    expect(
      normalizeTagPath(
        '#family\u{1F468}\u200D\u{1F469}\u200D\u{1F467}\u200D\u{1F466}',
      ),
      'family\u{1F468}\u200D\u{1F469}\u200D\u{1F467}\u200D\u{1F466}',
    );
  });

  test('extractTags ignores link fragments while keeping real tags', () {
    expect(
      extractTags(
        'Read [section](https://example.com/article#intro)\n\n[jump](#details)\n\n#Work',
      ),
      const <String>['Work'],
    );
  });

  test('extractTags ignores fenced code blocks while keeping real tags', () {
    expect(
      extractTags('''#real

```c
#include <stdio.h>
#define DEBUG 1
```

after #done'''),
      const <String>['real'],
    );
    expect(
      extractTags('''#real

```c
#include <stdio.h>
#define DEBUG 1
```

#done'''),
      const <String>['done', 'real'],
    );
  });

  test('extractTags ignores tilde fenced code blocks', () {
    expect(
      extractTags('''#visible

~~~dart
final value = '#hidden';
~~~

after'''),
      const <String>['visible'],
    );
  });

  test('extractTags ignores inline code spans while keeping prose tags', () {
    expect(
      extractTags('Use `#include` and `#not-a-tag`\n\n#cpp'),
      const <String>['cpp'],
    );
  });

  test('extractTags ignores protected hashes at tag-zone boundaries', () {
    expect(extractTags('[#hidden](https://example.com)'), isEmpty);
    expect(extractTags('![#hidden](https://example.com/image.png)'), isEmpty);
    expect(extractTags('https://example.com/article#intro'), isEmpty);
    expect(extractTags('`#hidden`'), isEmpty);
    expect(extractTags('```\n#hidden\n```'), isEmpty);
  });

  test('extractTags only scans strict first and last tag zones', () {
    expect(
      extractTags('''#first #top

- item #list-tag
> quoted #quote-tag

| Topic | Tag |
| - | - |
| Work | #table-tag |

plain #paragraph-tag

#bottom'''),
      const <String>['bottom', 'first', 'top'],
    );
  });

  test('extractTags ignores prose hash fragments', () {
    expect(extractTags('测试文本 #这是测试文本'), isEmpty);
    expect(extractTags('今天记录一下 #生活\n\n#real'), const <String>['real']);
  });

  test('extractTags accepts leading tag prefixes with trailing prose', () {
    expect(extractTags('#测试文本 测试文本'), const <String>['测试文本']);
    expect(
      extractTags('#first #top opening text\n\nbody\n\n#bottom closing text'),
      const <String>['bottom', 'first', 'top'],
    );
    expect(extractTags('#first text #ignored'), const <String>['first']);
  });

  test('extractTags ignores middle tag-looking lines', () {
    expect(extractTags('#first\n\n#middle-tag\n\n#last'), const <String>[
      'first',
      'last',
    ]);
  });

  test('extractTags treats MemoFlow internal markers as non-content lines', () {
    expect(
      extractTags('''# Example article

Captured body

#clip #reading

<!-- memoflow-third-party-share -->'''),
      const <String>['clip', 'reading'],
    );
    expect(
      extractTags('#queued\n\n<!-- memoflow_quick_clip:memo-1 -->'),
      const <String>['queued'],
    );
    expect(
      extractTags('#inline\n\n<!-- memoflow-share-inline:attachment-1 -->'),
      const <String>['inline'],
    );
  });

  test('extractTags ignores indented code block tag lines', () {
    expect(extractTags('    #hidden-code-tag'), isEmpty);
  });

  test('memosCompatible extracts inline Markdown text tags', () {
    final tags = extractTags(
      'Today #life.\n'
      '- Item #todo\n'
      '> Quote #quote\n'
      'Issue #123 #\u6D4B\u8BD5 #test\u{1F680} #work/\u9879\u76EE',
      policy: TagRecognitionPolicy.memosCompatible,
    );

    expect(
      tags,
      unorderedEquals(const <String>[
        '123',
        'life',
        'quote',
        'test\u{1F680}',
        'todo',
        'work/\u9879\u76EE',
        '\u6D4B\u8BD5',
      ]),
    );
  });

  test('custom policy follows enabled token options', () {
    final policy = TagRecognitionPolicy.custom(
      const TagRecognitionCustomOptions(
        inlineBodyTags: true,
        numericOnlyTags: false,
        hierarchicalTags: false,
        emojiAndSymbolTags: false,
      ),
    );

    final tags = extractTags(
      '#top #work/project #mood\u{1F680}\n\n'
      'Today #life Issue #123 #plain',
      policy: policy,
    );

    expect(tags, unorderedEquals(const <String>['life', 'plain', 'top']));
  });

  test('deriveVisibleMemoTags applies remote tag handling from policy', () {
    expect(
      deriveVisibleMemoTags(
        content: 'Today #life',
        remoteTags: const <String>['remote'],
        policy: TagRecognitionPolicy.memoflowStrict,
      ),
      isEmpty,
    );
    expect(
      deriveVisibleMemoTags(
        content: 'Today #life',
        remoteTags: const <String>['remote'],
        policy: TagRecognitionPolicy.memosCompatible,
      ),
      unorderedEquals(const <String>['life', 'remote']),
    );
    expect(
      deriveVisibleMemoTags(
        content: 'Today #life #123',
        remoteTags: const <String>['remote', '456'],
        policy: TagRecognitionPolicy.custom(
          const TagRecognitionCustomOptions(
            inlineBodyTags: true,
            numericOnlyTags: false,
            remoteTagHandling: RemoteTagHandling.mergeRemote,
          ),
        ),
      ),
      unorderedEquals(const <String>['life', 'remote']),
    );
  });

  test('protected Markdown contexts stay ignored under compatible policy', () {
    final tags = extractTags(
      'Use `#inlineCode`\n'
      '```dart\n#block\n```\n'
      '[#linkText](https://example.com/#fragment)\n'
      '![#image](https://example.com/image#asset)\n'
      'https://example.com/page#fragment\n'
      'Outside #real',
      policy: TagRecognitionPolicy.memosCompatible,
    );

    expect(tags, const <String>['real']);
  });
}
