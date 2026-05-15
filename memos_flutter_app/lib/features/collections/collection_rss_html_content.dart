import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;

class CollectionRssHtmlContent extends StatelessWidget {
  const CollectionRssHtmlContent({
    super.key,
    required this.html,
    required this.textStyle,
  });

  final String html;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      html,
      textStyle: textStyle,
      renderMode: RenderMode.column,
      customStylesBuilder: _rssHtmlStylesBuilder,
    );
  }
}

Map<String, String>? _rssHtmlStylesBuilder(dom.Element element) {
  final tag = element.localName?.toLowerCase() ?? '';
  if (tag == 'img') {
    return const <String, String>{
      'display': 'block',
      'height': 'auto',
      'margin': '12px 0',
      'max-width': '100%',
      'min-width': '0',
    };
  }
  if (tag == 'video') {
    return const <String, String>{
      'display': 'block',
      'height': 'auto',
      'margin': '12px 0',
      'max-width': '100%',
      'min-width': '0',
    };
  }
  if (tag == 'a' && element.querySelector('img,video') != null) {
    return const <String, String>{
      'display': 'block',
      'max-width': '100%',
      'min-width': '0',
    };
  }
  if (tag == 'figure') {
    return const <String, String>{
      'display': 'block',
      'margin': '12px 0',
      'max-width': '100%',
      'min-width': '0',
    };
  }
  return null;
}
