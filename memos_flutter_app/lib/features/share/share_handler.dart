import 'dart:async';

import 'package:flutter/services.dart';

enum SharePayloadType { text, images }

class SharePayload {
  const SharePayload({
    required this.type,
    this.text,
    this.title,
    this.paths = const [],
  });

  final SharePayloadType type;
  final String? text;
  final String? title;
  final List<String> paths;

  static SharePayload? fromArgs(Object? args) {
    if (args is! Map) return null;
    final rawType = args['type'];
    final type = _parseType(rawType);
    if (type == null) return null;
    final text = args['text'] as String?;
    final title = _normalizeTitle(args['title'] as String?);
    final rawPaths = args['paths'];
    final paths = <String>[];
    if (rawPaths is List) {
      for (final item in rawPaths) {
        if (item is String && item.trim().isNotEmpty) {
          paths.add(item);
        }
      }
    }
    return SharePayload(type: type, text: text, title: title, paths: paths);
  }

  static SharePayloadType? _parseType(Object? raw) {
    if (raw is! String) return null;
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'images' || normalized == 'image') {
      return SharePayloadType.images;
    }
    if (normalized == 'text' || normalized == 'url') {
      return SharePayloadType.text;
    }
    return null;
  }

  static String? _normalizeTitle(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty || _looksLikeUrl(normalized)) {
      return null;
    }
    return normalized;
  }
}

class ShareTextDraft {
  const ShareTextDraft({required this.text, required this.selectionOffset});

  final String text;
  final int selectionOffset;
}

ShareTextDraft buildShareTextDraft(SharePayload payload) {
  final rawText = (payload.text ?? '').trim();
  final url = extractShareUrl(rawText);
  if (url == null) {
    return ShareTextDraft(text: rawText, selectionOffset: rawText.length);
  }

  final title = _extractShareTitle(
    payload: payload,
    rawText: rawText,
    url: url,
  );
  if (title == null) {
    return ShareTextDraft(text: '[]($url)', selectionOffset: 1);
  }

  final text = '[${_escapeMarkdownLinkText(title)}]($url)';
  return ShareTextDraft(text: text, selectionOffset: text.length);
}

String? extractShareUrl(String raw) {
  final normalized = raw.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
  final match = RegExp(
    r'https?://[^\s<>\u3000]+',
    caseSensitive: false,
  ).firstMatch(normalized);
  final url = _trimTrailingUrlPunctuation(match?.group(0));
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return url;
}

String? _trimTrailingUrlPunctuation(String? rawUrl) {
  if (rawUrl == null) return null;
  var trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;
  while (trimmed.isNotEmpty) {
    final last = trimmed[trimmed.length - 1];
    if (_alwaysTrimTrailingUrlPunctuation.contains(last)) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
      continue;
    }
    final opening = _balancedTrailingCloserPairs[last];
    if (opening != null &&
        _countOccurrences(trimmed, last) >
            _countOccurrences(trimmed, opening)) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
      continue;
    }
    break;
  }
  return trimmed.isEmpty ? null : trimmed;
}

const Set<String> _alwaysTrimTrailingUrlPunctuation = {
  '.',
  ',',
  ';',
  ':',
  '!',
  '?',
  '\'',
  '"',
  '\u3001',
  '\u3002',
  '\uFF0C',
  '\uFF1B',
  '\uFF1A',
  '\uFF01',
  '\uFF1F',
  '\u2019',
  '\u201D',
};

const Map<String, String> _balancedTrailingCloserPairs = {
  ')': '(',
  ']': '[',
  '}': '{',
  '\u300D': '\u300C',
  '\u300F': '\u300E',
  '\u3011': '\u3010',
  '\uFF09': '\uFF08',
};

int _countOccurrences(String value, String needle) {
  var count = 0;
  for (var index = 0; index < value.length; index++) {
    if (value[index] == needle) {
      count++;
    }
  }
  return count;
}

String? _extractShareTitle({
  required SharePayload payload,
  required String rawText,
  required String url,
}) {
  final explicitTitle = SharePayload._normalizeTitle(payload.title);
  if (explicitTitle != null) return explicitTitle;

  final derivedText = rawText.replaceFirst(url, ' ');
  return SharePayload._normalizeTitle(derivedText);
}

String _escapeMarkdownLinkText(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]');
}

bool _looksLikeUrl(String value) {
  return RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(value);
}

class ShareHandlerService {
  static const MethodChannel _channel = MethodChannel('memoflow/share');

  static void setShareHandler(
    FutureOr<void> Function(SharePayload payload) handler,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openShare') return;
      final payload = SharePayload.fromArgs(call.arguments);
      if (payload == null) return;
      await handler(payload);
    });
  }

  static Future<SharePayload?> consumePendingShare() async {
    try {
      final args = await _channel.invokeMethod<Object>('getPendingShare');
      return SharePayload.fromArgs(args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
