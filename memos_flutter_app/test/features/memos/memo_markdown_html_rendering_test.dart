import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/memo_markdown.dart';

void main() {
  testWidgets('renders embedded full HTML document as code block', (
    WidgetTester tester,
  ) async {
    const content =
        '完整 HTML 文档（以开头）会按“代码块”显示，不会当页面执行渲染。\n\n'
        '<!DOCTYPE html>\n'
        '<html>\n'
        '<head>\n'
        '<title>最小示例</title>\n'
        '</head>\n'
        '<body>\n'
        '<p>Hello, World!</p>\n'
        '</body>\n'
        '</html>';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MemoMarkdown(data: content)),
      ),
    );
    await tester.pumpAndSettle();

    final rendered = _collectRenderedText(tester);

    expect(rendered, contains('<!DOCTYPE html>'));
    expect(rendered, contains('<p>Hello, World!</p>'));
    expect(rendered, isNot(contains('Hello, World!\n')));
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
