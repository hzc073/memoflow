import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/features/memos/memo_card_preview.dart';

void main() {
  test('truncates long preview text', () {
    final content = List<String>.filled(8, 'line').join('\n');

    final result = truncateMemoCardPreview(content, collapseLongContent: true);

    expect(result.truncated, isTrue);
    expect(result.text, contains('...'));
  });

  test('preserves markdown links when truncating', () {
    final content =
        '${List<String>.filled(218, 'a').join()} [OpenAI](https://openai.com) tail';

    final result = truncateMemoCardPreview(content, collapseLongContent: true);

    expect(result.truncated, isTrue);
    expect(result.text, contains('[OpenAI](https://openai.com)'));
  });

  test('collapses quoted lines into summary when enabled', () {
    final previewText = buildMemoCardPreviewText(
      'Main line\n> Quote 1\n> Quote 2',
      collapseReferences: true,
      language: AppLanguage.en,
    );

    expect(previewText, 'Main line\n\nQuoted 2 lines');
  });
}
