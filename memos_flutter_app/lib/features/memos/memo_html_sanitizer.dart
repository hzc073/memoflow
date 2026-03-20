import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const String _mathInlineTag = 'memo-math-inline';
const String _mathBlockTag = 'memo-math-block';

const Set<String> _blockedHtmlTags = {'script', 'style'};

const Set<String> _allowedHtmlTags = {
  'a',
  'blockquote',
  'br',
  'code',
  'del',
  'details',
  'em',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'hr',
  'img',
  'input',
  'li',
  'ol',
  'p',
  'pre',
  'summary',
  'span',
  'strong',
  'sub',
  'sup',
  'table',
  'tbody',
  'td',
  'th',
  'thead',
  'tr',
  'ul',
  _mathInlineTag,
  _mathBlockTag,
};

const Map<String, Set<String>> _allowedHtmlAttributes = {
  'a': {'href', 'title'},
  'img': {'src', 'alt', 'title', 'width', 'height'},
  'code': {'class'},
  'pre': {'class'},
  'span': {'class', 'data-tag'},
  'li': {'class'},
  'ul': {'class'},
  'ol': {'class'},
  'p': {'class'},
  'details': {'open'},
  'input': {'type', 'checked', 'disabled'},
};

final List<RegExp> _allowedClassPatterns = [
  RegExp(r'^memotag$'),
  RegExp(r'^memohighlight$'),
  RegExp(r'^memo-blank-line$'),
  RegExp(r'^task-list-item$'),
  RegExp(r'^contains-task-list$'),
  RegExp(r'^language-[\w-]+$'),
];

String sanitizeMemoHtml(String html) {
  final fragment = html_parser.parseFragment(html);
  _sanitizeDomNode(fragment);
  return fragment.outerHtml;
}

void _sanitizeDomNode(dom.Node node) {
  final children = node.nodes.toList(growable: false);
  for (final child in children) {
    if (child is dom.Element) {
      _sanitizeElement(child);
      continue;
    }
    if (child.nodeType == dom.Node.COMMENT_NODE) {
      child.remove();
    }
  }
}

void _sanitizeElement(dom.Element element) {
  final tag = element.localName;
  if (tag == null) {
    element.remove();
    return;
  }
  if (_blockedHtmlTags.contains(tag)) {
    element.remove();
    return;
  }
  if (!_allowedHtmlTags.contains(tag)) {
    _unwrapElement(element);
    return;
  }
  if (!_sanitizeAttributes(element, tag)) {
    return;
  }
  if (tag == 'pre' || tag == 'code') {
    return;
  }
  _sanitizeDomNode(element);
}

bool _sanitizeAttributes(dom.Element element, String tag) {
  final allowedAttrs = _allowedHtmlAttributes[tag] ?? const <String>{};
  final attributes = Map<String, String>.from(element.attributes);
  element.attributes.clear();
  for (final entry in attributes.entries) {
    if (!allowedAttrs.contains(entry.key)) continue;
    element.attributes[entry.key] = entry.value;
  }

  if (element.attributes.containsKey('class')) {
    final filtered = _filterClasses(element.attributes['class']);
    if (filtered == null) {
      element.attributes.remove('class');
    } else {
      element.attributes['class'] = filtered;
    }
  }

  if (tag == 'a') {
    final href = _sanitizeUrl(
      element.attributes['href'],
      allowRelative: true,
      allowMailto: true,
    );
    if (href == null) {
      _unwrapElement(element);
      return false;
    }
    element.attributes['href'] = href;
  }

  if (tag == 'img') {
    final src = _sanitizeUrl(
      element.attributes['src'],
      allowRelative: true,
      allowMailto: false,
    );
    if (src == null) {
      element.remove();
      return false;
    }
    element.attributes['src'] = src;
  }

  if (tag == 'input') {
    final type = element.attributes['type']?.toLowerCase();
    if (type != 'checkbox') {
      element.remove();
      return false;
    }
  }

  return true;
}

String? _filterClasses(String? value) {
  if (value == null) return null;
  final classes = value
      .split(RegExp(r'\s+'))
      .where((c) => c.isNotEmpty && _isAllowedClass(c))
      .toList(growable: false);
  if (classes.isEmpty) return null;
  return classes.join(' ');
}

bool _isAllowedClass(String value) {
  for (final pattern in _allowedClassPatterns) {
    if (pattern.hasMatch(value)) return true;
  }
  return false;
}

String? _sanitizeUrl(
  String? url, {
  required bool allowRelative,
  required bool allowMailto,
}) {
  if (url == null) return null;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.hasScheme) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') return trimmed;
    if (allowMailto && scheme == 'mailto') return trimmed;
    return null;
  }
  if (!allowRelative) return null;
  return trimmed;
}

void _unwrapElement(dom.Element element) {
  final parent = element.parent;
  if (parent == null) {
    element.remove();
    return;
  }
  final index = parent.nodes.indexOf(element);
  final children = element.nodes.toList(growable: false);
  element.remove();
  if (children.isNotEmpty) {
    parent.nodes.insertAll(index, children);
    for (final child in children) {
      _sanitizeDomNode(child);
    }
  }
}
