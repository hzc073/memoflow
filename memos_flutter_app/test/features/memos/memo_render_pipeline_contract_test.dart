import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/memo_image_src_normalizer.dart';
import 'package:memos_flutter_app/features/memos/memo_markdown_preprocessor.dart';
import 'package:memos_flutter_app/features/memos/memo_render_pipeline.dart';

void main() {
  final pipeline = MemoRenderPipeline();

  test('full html document renders through code block mode', () {
    const content =
        '<!DOCTYPE html>\n'
        '<html>\n'
        '<head><title>Hello</title></head>\n'
        '<body><p>Hello</p></body>\n'
        '</html>';

    final artifact = pipeline.build(data: content, renderImages: true);

    expect(artifact.mode, MemoRenderMode.codeBlock);
    expect(artifact.content, content);
  });

  test('embedded full html document is wrapped as escaped fenced html', () {
    const content =
        'intro\n\n'
        '<!DOCTYPE html>\n'
        '<html>\n'
        '<body>\n'
        '<p>Hello</p>\n'
        '</body>\n'
        '</html>';

    final artifact = pipeline.build(data: content, renderImages: true);

    expect(artifact.mode, MemoRenderMode.html);
    expect(artifact.content, contains('<pre><code class="language-html">'));
    expect(artifact.content, contains('&lt;!DOCTYPE html&gt;'));
    expect(artifact.content, contains('&lt;p&gt;Hello&lt;/p&gt;'));
    expect(artifact.content, isNot(contains('<p>Hello</p>')));
  });

  test('empty markdown links collapse to text and images stay intact', () {
    const content = 'Open [](/docs)\n\n![](https://example.com/image.png)';

    final artifact = pipeline.build(data: content, renderImages: true);

    expect(artifact.content, contains('/docs'));
    expect(
      artifact.content,
      contains('<img src="https://example.com/image.png"'),
    );
  });

  test(
    'preprocessor preserves explicit blank lines with html placeholders',
    () {
      expect(
        sanitizeMemoMarkdown('Alpha\n\nBeta'),
        'Alpha\n\n<p class="memo-blank-line">\u200B</p>\n\nBeta',
      );
      expect(
        sanitizeMemoMarkdown('- item\n\nParagraph'),
        '- item\n\n<p class="memo-blank-line">\u200B</p>\n\nParagraph',
      );
    },
  );

  test('search highlight skips code and memo tag subtrees', () {
    const content = '#tag\n\n`keyword` plain keyword';

    final artifact = pipeline.build(
      data: content,
      renderImages: true,
      highlightQuery: 'tag keyword',
    );

    expect(_countMatches(artifact.content, 'class="memohighlight"'), 1);
    expect(artifact.content, contains('class="memotag"'));
    expect(artifact.content, contains('<code>keyword</code>'));
  });

  test('image src normalizer keeps blob to raw conversions stable', () {
    expect(
      normalizeMarkdownImageSrc('https://github.com/o/r/blob/main/a.png'),
      'https://raw.githubusercontent.com/o/r/main/a.png',
    );
    expect(
      normalizeMarkdownImageSrc('https://gitlab.com/o/r/-/blob/main/a.png'),
      'https://gitlab.com/o/r/-/raw/main/a.png',
    );
    expect(
      normalizeMarkdownImageSrc('https://gitee.com/o/r/blob/main/a.png'),
      'https://gitee.com/o/r/raw/main/a.png',
    );
  });
}

int _countMatches(String text, String pattern) {
  return RegExp(RegExp.escape(pattern)).allMatches(text).length;
}
