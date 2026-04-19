import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/memo_markdown.dart';

void main() {
  test('resolveMemoMarkdownRemoteImageRequest resolves relative file urls', () {
    final request = resolveMemoMarkdownRemoteImageRequest(
      rawSrc: '/file/resources/demo/image.webp',
      baseUrl: Uri.parse('http://192.168.13.13:45230'),
      authHeader: 'Bearer token',
    );

    expect(request, isNotNull);
    expect(
      request?.url,
      'http://192.168.13.13:45230/file/resources/demo/image.webp',
    );
    expect(request?.headers, {'Authorization': 'Bearer token'});
  });

  test(
    'resolveMemoMarkdownRemoteImageRequest ignores local file image urls',
    () {
      final request = resolveMemoMarkdownRemoteImageRequest(
        rawSrc: 'file:///tmp/memo-inline.webp',
        baseUrl: Uri.parse('http://192.168.13.13:45230'),
        authHeader: 'Bearer token',
      );

      expect(request, isNull);
    },
  );

  testWidgets('MemoMarkdown emits stable checkbox indices in UI order', (
    WidgetTester tester,
  ) async {
    final requests = <TaskToggleRequest>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoMarkdown(
            data: '- [ ] first\n- [x] second\n- [ ] third',
            onToggleTask: requests.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pump();
    await tester.tap(find.byType(InkWell).at(1));
    await tester.pump();

    expect(requests.length, 2);
    expect(requests[0].taskIndex, 0);
    expect(requests[0].checked, isFalse);
    expect(requests[1].taskIndex, 1);
    expect(requests[1].checked, isTrue);
  });

  testWidgets('MemoMarkdown renderImages false strips markdown image syntax', (
    WidgetTester tester,
  ) async {
    const content = 'before\n\n![alt](https://example.com/image.png)\n\nafter';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MemoMarkdown(data: content, renderImages: false)),
      ),
    );
    await tester.pumpAndSettle();

    final rendered = _collectRenderedText(tester);

    expect(rendered, contains('before'));
    expect(rendered, contains('after'));
    expect(rendered, isNot(contains('alt')));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

String _collectRenderedText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    final value = richText.text.toPlainText();
    if (value.trim().isNotEmpty) {
      buffer.writeln(value);
    }
  }
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final span = text.textSpan;
    final value = span?.toPlainText() ?? text.data;
    if (value != null && value.trim().isNotEmpty) {
      buffer.writeln(value);
    }
  }
  return buffer.toString();
}
