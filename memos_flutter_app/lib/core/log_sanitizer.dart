import 'dart:convert';

class LogSanitizer {
  static String maskUserLabel(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (s.contains('@')) {
      final parts = s.split('@');
      if (parts.length == 2) {
        final local = parts.first;
        final domain = parts.last;
        return '${_maskValue(local, keepStart: 1, keepEnd: 0)}@${maskHost(domain)}';
      }
    }
    if (s.contains('/')) {
      final pieces = s.split('/');
      if (pieces.length > 1) {
        final last = pieces.removeLast();
        pieces.add(_maskValue(last, keepStart: 1, keepEnd: 1));
        return pieces.join('/');
      }
    }
    return _maskValue(s, keepStart: 1, keepEnd: 1);
  }

  static String maskToken(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    return _maskValue(s, keepStart: 4, keepEnd: 2);
  }

  static String maskHost(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (_ipv4Regex.hasMatch(s)) {
      final parts = s.split('.');
      if (parts.length == 4) {
        parts[3] = '*';
        return parts.join('.');
      }
    }
    if (s.contains(':') && !s.contains('.')) {
      return _maskValue(s, keepStart: 2, keepEnd: 2);
    }
    final labels = s.split('.');
    if (labels.length <= 1) {
      return _maskValue(s, keepStart: 1, keepEnd: 1);
    }
    final out = <String>[];
    for (var i = 0; i < labels.length; i++) {
      final label = labels[i];
      if (i == labels.length - 1) {
        out.add(label);
      } else {
        out.add(_maskValue(label, keepStart: 1, keepEnd: 1));
      }
    }
    return out.join('.');
  }

  static String maskUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    Uri? uri = Uri.tryParse(s);
    final hasScheme = uri != null && uri.scheme.isNotEmpty;
    if (uri == null || uri.host.isEmpty) {
      final alt = Uri.tryParse('http://$s');
      if (alt == null || alt.host.isEmpty) {
        return _maskValue(s, keepStart: 2, keepEnd: 2);
      }
      uri = alt;
    }

    final scheme = hasScheme && uri.scheme.isNotEmpty ? '${uri.scheme}://' : '';
    final host = uri.host.isNotEmpty ? maskHost(uri.host) : '';
    final port = uri.hasPort ? ':${uri.port}' : '';
    final path = uri.path;
    final query = _sanitizeQuery(uri.queryParametersAll);
    final fragment = uri.fragment.isNotEmpty ? '#${uri.fragment}' : '';
    final queryPart = query.isNotEmpty ? '?$query' : '';
    return '$scheme$host$port$path$queryPart$fragment';
  }

  static String sanitizeText(String raw) {
    var s = raw;
    s = s.replaceAllMapped(_bearerRegex, (m) {
      final token = m.group(1) ?? '';
      return 'Bearer ${maskToken(token)}';
    });
    s = s.replaceAllMapped(_tokenParamRegex, (m) {
      final key = m.group(1) ?? '';
      final value = m.group(2) ?? '';
      return '$key=${maskToken(value)}';
    });
    s = s.replaceAllMapped(_urlRegex, (m) => maskUrl(m.group(0) ?? ''));
    return s;
  }

  static Object? sanitizeJson(Object? value) {
    if (value == null) return null;
    if (value is Map) {
      final out = <String, Object?>{};
      value.forEach((key, v) {
        final k = key.toString();
        out[k] = _sanitizeByKey(k, v);
      });
      return out;
    }
    if (value is List) {
      return value.map(sanitizeJson).toList(growable: false);
    }
    if (value is String) {
      final trimmed = value.trim();
      if (_looksLikeJson(trimmed)) {
        try {
          final decoded = jsonDecode(trimmed);
          return sanitizeJson(decoded);
        } catch (_) {}
      }
      return _sanitizeString(value);
    }
    return value;
  }

  static String stringify(Object? value, {int maxLength = 1200}) {
    if (value == null) return '';
    String text;
    if (value is String) {
      text = value;
    } else {
      try {
        text = jsonEncode(value);
      } catch (_) {
        text = value.toString();
      }
    }
    if (text.length <= maxLength) return text;
    final truncated = text.substring(0, maxLength);
    return '$truncated...(${text.length} chars)';
  }

  static Object? _sanitizeByKey(String key, Object? value) {
    final lower = key.trim().toLowerCase();
    if (value == null) return null;
    if (_isSensitiveKey(lower)) {
      return maskToken(value.toString());
    }
    if (_isContentKey(lower)) {
      return _redactContent(value);
    }
    if (_isUrlKey(lower)) {
      return maskUrl(value.toString());
    }
    if (_isUserKey(lower) && value is! Map && value is! List) {
      return maskUserLabel(value.toString());
    }
    if (lower == 'name' && value is String) {
      final v = value.trim();
      if (v.startsWith('users/') || v.contains('@')) {
        return maskUserLabel(v);
      }
    }
    return sanitizeJson(value);
  }

  static String _sanitizeString(String value) {
    final s = value.trim();
    if (s.isEmpty) return s;
    if (_looksLikeBase64(s)) {
      return '<base64:${s.length}>';
    }
    return sanitizeText(s);
  }

  static String _redactContent(Object? value) {
    if (value == null) return '<redacted:0>';
    if (value is String) return '<redacted:${value.length}>';
    if (value is List) return '<redacted:${value.length}>';
    return '<redacted>';
  }

  static bool _looksLikeBase64(String value) {
    if (value.length < 80) return false;
    if (!_base64Regex.hasMatch(value)) return false;
    return true;
  }

  static bool _looksLikeJson(String value) {
    if (value.isEmpty) return false;
    final first = value[0];
    return first == '{' || first == '[';
  }

  static bool _isSensitiveKey(String key) {
    return key.contains('token') ||
        key.contains('secret') ||
        key.contains('password') ||
        key == 'authorization' ||
        key == 'cookie' ||
        key == 'set-cookie';
  }

  static bool _isContentKey(String key) {
    return key == 'content' || key == 'snippet';
  }

  static bool _isUserKey(String key) {
    return key.contains('user') ||
        key.contains('username') ||
        key.contains('displayname') ||
        key.contains('display_name') ||
        key.contains('email') ||
        key.contains('creator') ||
        key.contains('owner');
  }

  static bool _isUrlKey(String key) {
    return key.contains('url') ||
        key.contains('host') ||
        key.contains('server') ||
        key.contains('base') ||
        key.contains('avatar');
  }

  static String _sanitizeQuery(Map<String, List<String>> params) {
    final pairs = <String>[];
    for (final entry in params.entries) {
      final key = entry.key;
      final values = entry.value;
      if (values.isEmpty) {
        pairs.add(Uri.encodeQueryComponent(key));
        continue;
      }
      for (final value in values) {
        final sanitized = _isSensitiveKey(key.toLowerCase()) ? maskToken(value) : value;
        pairs.add('${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(sanitized)}');
      }
    }
    return pairs.join('&');
  }

  static String _maskValue(String raw, {required int keepStart, required int keepEnd}) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    final runes = s.runes.toList();
    final length = runes.length;
    final startCount = keepStart.clamp(0, length);
    final endCount = keepEnd.clamp(0, length - startCount);
    if (length <= startCount + endCount) {
      if (length == 1) return '*';
      final head = String.fromCharCode(runes.first);
      return '$head${_repeatMask(length - 1)}';
    }
    final start = runes.take(startCount).map(String.fromCharCode).join();
    final end = runes.skip(length - endCount).map(String.fromCharCode).join();
    final midCount = length - startCount - endCount;
    return '$start${_repeatMask(midCount)}$end';
  }

  static String _repeatMask(int count) {
    if (count <= 0) return '';
    return List.filled(count, '*').join();
  }

  static final RegExp _ipv4Regex = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
  static final RegExp _bearerRegex = RegExp(r'Bearer\s+([A-Za-z0-9\-\._=]+)', caseSensitive: false);
  static final RegExp _tokenParamRegex = RegExp(
    r'(token|access_token|refresh_token)=([^\s&]+)',
    caseSensitive: false,
  );
  static final RegExp _urlRegex = RegExp(r'https?://[^\s)]+');
  static final RegExp _base64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
}
