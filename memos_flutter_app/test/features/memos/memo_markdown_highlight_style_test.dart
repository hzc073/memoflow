import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/memo_markdown.dart';

void main() {
  testWidgets('inline highlight uses inline display style', (
    WidgetTester tester,
  ) async {
    const content = '高亮（自定义语法）\n\n==这段会高亮==';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MemoMarkdown(data: content)),
      ),
    );
    await tester.pumpAndSettle();

    final rendered = _collectRenderedText(tester);
    expect(rendered, contains('这段会高亮'));
    expect(rendered, isNot(contains('==这段会高亮==')));
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
