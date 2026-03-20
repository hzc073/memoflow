import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/memo_markdown.dart';

void main() {
  testWidgets('preserves explicit blank lines in plain paragraph text', (
    WidgetTester tester,
  ) async {
    const content = 'line1\n\nline2';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MemoMarkdown(data: content)),
      ),
    );
    await tester.pumpAndSettle();

    final rendered = _collectRenderedText(tester);

    expect(rendered, contains('line1'));
    expect(rendered, contains('line2'));
    expect(rendered, contains('\u200B'));
  });

  testWidgets('preserves blank lines after unordered list content', (
    WidgetTester tester,
  ) async {
    const content = '- item\n\nparagraph';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MemoMarkdown(data: content)),
      ),
    );
    await tester.pumpAndSettle();

    final rendered = _collectRenderedText(tester);

    expect(rendered, contains('item'));
    expect(rendered, contains('paragraph'));
    expect(rendered, contains('\u200B'));
  });

  testWidgets('preserves multiple explicit blank lines between blocks', (
    WidgetTester tester,
  ) async {
    const content = 'line1\n\n\nline2';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MemoMarkdown(data: content)),
      ),
    );
    await tester.pumpAndSettle();

    final rendered = _collectRenderedText(tester);

    expect(rendered, contains('line1'));
    expect(rendered, contains('line2'));
    expect(_countOccurrences(rendered, '\u200B'), greaterThanOrEqualTo(2));
  });
}

String _collectRenderedText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    final value = richText.text.toPlainText();
    if (value.isNotEmpty) {
      buffer.writeln(value);
    }
  }
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final span = text.textSpan;
    final value = span?.toPlainText() ?? text.data;
    if (value != null && value.isNotEmpty) {
      buffer.writeln(value);
    }
  }
  return buffer.toString();
}

int _countOccurrences(String value, String pattern) {
  return RegExp(RegExp.escape(pattern)).allMatches(value).length;
}
