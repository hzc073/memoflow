import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/share/share_handler.dart';

void main() {
  group('buildShareTextDraft', () {
    test('uses explicit title from payload when available', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/article',
        title: 'Example Article',
      );

      final draft = buildShareTextDraft(payload);

      expect(draft.text, '[Example Article](https://example.com/article)');
      expect(draft.selectionOffset, draft.text.length);
    });

    test('derives title from shared browser text', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'Example Article\nhttps://example.com/article',
      );

      final draft = buildShareTextDraft(payload);

      expect(draft.text, '[Example Article](https://example.com/article)');
      expect(draft.selectionOffset, draft.text.length);
    });

    test('keeps empty link label when only url is shared', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/article',
      );

      final draft = buildShareTextDraft(payload);

      expect(draft.text, '[](https://example.com/article)');
      expect(draft.selectionOffset, 1);
    });

    test('keeps plain text when there is no url', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'just some text',
      );

      final draft = buildShareTextDraft(payload);

      expect(draft.text, 'just some text');
      expect(draft.selectionOffset, draft.text.length);
    });
  });

  test('SharePayload.fromArgs normalizes title', () {
    final payload = SharePayload.fromArgs(<String, Object?>{
      'type': 'text',
      'text': 'https://example.com/article',
      'title': '  Example   Article  ',
    });

    expect(payload, isNotNull);
    expect(payload!.title, 'Example Article');
  });

  test(
    'extractShareUrl returns the first url when multiple urls are shared',
    () {
      const raw =
          'Read this https://example.com/one and also https://example.com/two';

      final url = extractShareUrl(raw);

      expect(url, 'https://example.com/one');
    },
  );

  test('extractShareUrl trims trailing punctuation from shared text', () {
    const raw = 'Read this https://example.com/one.';

    final url = extractShareUrl(raw);

    expect(url, 'https://example.com/one');
  });

  test('extractShareUrl preserves valid urls ending with a parenthesis', () {
    const raw = 'https://en.wikipedia.org/wiki/Function_(mathematics)';

    final url = extractShareUrl(raw);

    expect(url, raw);
  });

  test(
    'extractShareUrl keeps balanced closing parenthesis before sentence punctuation',
    () {
      const raw = 'See https://en.wikipedia.org/wiki/Function_(mathematics).';

      final url = extractShareUrl(raw);

      expect(url, 'https://en.wikipedia.org/wiki/Function_(mathematics)');
    },
  );

  test('extractShareUrl trims wrapper closing parenthesis', () {
    const raw = '(https://example.com/one)';

    final url = extractShareUrl(raw);

    expect(url, 'https://example.com/one');
  });

  test('extractShareUrl trims full-width wrapper closing parenthesis', () {
    const raw = '\uFF08https://example.com/one\uFF09';

    final url = extractShareUrl(raw);

    expect(url, 'https://example.com/one');
  });

  test('extractShareUrl ignores zero-width characters in clipboard text', () {
    const raw = 'https://example.com/one\u200b';

    final url = extractShareUrl(raw);

    expect(url, 'https://example.com/one');
  });
}
