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
    final path = _decodePath(uri.path);
    final query = _sanitizeQuery(uri.queryParametersAll);
    final fragment = uri.fragment.isNotEmpty ? '#${uri.fragment}' : '';
    final queryPart = query.isNotEmpty ? '?$query' : '';
    return '$scheme$host$port$path$queryPart$fragment';
  }

  static String fingerprint(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    return _hashText(s);
  }

  static String redactWithFingerprint(String raw, {required String kind}) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    final normalizedKind = _normalizeKind(kind);
    return '<${normalizedKind}_redacted:${fingerprint(s)}>';
  }

  static String redactPathLike(String raw) {
    return redactWithFingerprint(raw, kind: 'path');
  }

  static String redactOpaque(String raw, {String kind = 'opaque'}) {
    return redactWithFingerprint(raw, kind: kind);
  }

  static String redactSemanticText(String raw, {required String kind}) {
    final normalized = kind.trim().isEmpty ? 'text' : kind.trim();
    return redactWithFingerprint(raw, kind: normalized);
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
    s = s.replaceAllMapped(_workspaceKeyRegex, (m) {
      final value = m.group(0) ?? '';
      return redactOpaque(value);
    });
    s = s.replaceAllMapped(_windowsPathRegex, (m) {
      final value = m.group(0) ?? '';
      return redactPathLike(value);
    });
    s = s.replaceAllMapped(_uncPathRegex, (m) {
      final value = m.group(0) ?? '';
      return redactPathLike(value);
    });
    s = s.replaceAllMapped(_fileUriRegex, (m) {
      final value = m.group(0) ?? '';
      return redactPathLike(value);
    });
    s = s.replaceAllMapped(_debugPathPrefixRegex, (m) {
      final value = m.group(0) ?? '';
      return redactPathLike(value);
    });
    s = s.replaceAllMapped(_coordinatePairRegex, (m) {
      final value = m.group(0) ?? '';
      return redactSemanticText(value, kind: 'location');
    });
    s = s.replaceAllMapped(_urlRegex, (m) => maskUrl(m.group(0) ?? ''));
    return s;
  }

  static Map<String, String> sanitizeHeaders(Map<String, String> headers) {
    final out = <String, String>{};
    headers.forEach((key, value) {
      final lower = key.trim().toLowerCase();
      if (_isSensitiveKey(lower)) {
        out[key] = maskToken(value);
      } else {
        out[key] = sanitizeText(value);
      }
    });
    return out;
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
    final normalized = _normalizeKey(key);
    if (value == null) return null;

    if (_isSessionKey(normalized) && value is! Map && value is! List) {
      return redactOpaque(value.toString());
    }
    if (_isPaginationTokenKey(normalized) && value is! Map && value is! List) {
      return redactOpaque(value.toString());
    }
    if (_isCoordinatePairKey(normalized) && value is! Map && value is! List) {
      return redactSemanticText(value.toString(), kind: 'location');
    }
    if (_isCoordinateKey(normalized) && value is! Map && value is! List) {
      return redactSemanticText(value.toString(), kind: 'coord');
    }
    if (_isLocationNameKey(normalized) && value is! Map && value is! List) {
      return redactSemanticText(
        value.toString(),
        kind: _semanticKindForKey(normalized),
      );
    }
    if (_isContentKey(normalized)) {
      return _redactContent(value);
    }
    if (_isPathKey(normalized) && value is! Map && value is! List) {
      return _sanitizePathKeyValue(normalized, value.toString());
    }
    if (_isSourceKey(normalized) && value is String) {
      return _sanitizeSourceValue(value);
    }
    if (_isEntryKey(normalized) && value is String) {
      return _sanitizeEntryValue(value);
    }
    if (_isFileKey(normalized) && value is String) {
      return _sanitizeFileValue(value);
    }
    if (_isSensitiveKey(lower)) {
      return maskToken(value.toString());
    }
    if (_isUrlKey(lower)) {
      return maskUrl(value.toString());
    }
    if (_isUserKey(lower) && value is! Map && value is! List) {
      return maskUserLabel(value.toString());
    }
    if (normalized == 'name' && value is String) {
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
    final lower = key.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (lower == 'authorization' ||
        lower == 'cookie' ||
        lower == 'set-cookie') {
      return true;
    }
    if (lower.contains('token') ||
        lower.contains('secret') ||
        lower.contains('password')) {
      return true;
    }
    if (_matchesPatKey(lower) ||
        _matchesApiKey(lower) ||
        _matchesAuthKey(lower) ||
        _matchesSignatureKey(lower) ||
        _matchesGenericKey(lower)) {
      return true;
    }
    return false;
  }

  static bool _matchesPatKey(String key) {
    if (key.contains('personalaccesstoken') ||
        key.contains('personal_access_token')) {
      return true;
    }
    if (key == 'pat' || key.endsWith('_pat') || key.endsWith('-pat')) {
      return true;
    }
    return false;
  }

  static bool _matchesApiKey(String key) {
    if (key.contains('apikey') ||
        key.contains('api_key') ||
        key.contains('api-key')) {
      return true;
    }
    return false;
  }

  static bool _matchesAuthKey(String key) {
    if (key == 'auth') return true;
    if (key.startsWith('auth')) return true;
    if (key.contains('_auth') || key.contains('-auth')) return true;
    return false;
  }

  static bool _matchesSignatureKey(String key) {
    if (key.contains('signature')) return true;
    if (key == 'sig' || key.endsWith('_sig') || key.endsWith('-sig')) {
      return true;
    }
    return false;
  }

  static bool _matchesGenericKey(String key) {
    if (key == 'key') return true;
    if (key.endsWith('_key') || key.endsWith('-key')) return true;
    return false;
  }

  static bool _isContentKey(String key) {
    return key == 'content' || key == 'snippet';
  }

  static bool _isCoordinateKey(String key) {
    return key == 'lat' ||
        key == 'lng' ||
        key == 'lon' ||
        key.endsWith('latitude') ||
        key.endsWith('longitude');
  }

  static bool _isCoordinatePairKey(String key) {
    return key == 'location' ||
        key == 'position' ||
        key == 'coordinate' ||
        key == 'coordinates' ||
        key == 'loc';
  }

  static bool _isLocationNameKey(String key) {
    return key == 'placeholder' ||
        key == 'initialplaceholder' ||
        key == 'locationname' ||
        key == 'poiname' ||
        key == 'query' ||
        key == 'title' ||
        key == 'subtitle' ||
        key == 'city' ||
        key == 'reversegeocodelabel';
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

  static bool _isSessionKey(String key) {
    return key == 'sessionkey' ||
        key == 'currentkey' ||
        key == 'previouskey' ||
        key == 'nextkey' ||
        key == 'pendingworkspacekey' ||
        key == 'locationkey';
  }

  static bool _isPaginationTokenKey(String key) {
    return key == 'pagetoken' || key == 'nextpagetoken';
  }

  static bool _isPathKey(String key) {
    return key == 'path' ||
        key == 'filepath' ||
        key == 'rootpath' ||
        key == 'treeuri' ||
        key == 'filename' ||
        key == 'file';
  }

  static bool _isSourceKey(String key) {
    return key == 'source';
  }

  static bool _isEntryKey(String key) {
    return key == 'entry';
  }

  static bool _isFileKey(String key) {
    return key == 'file';
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
        final sanitizedValue = _sanitizeByKey(key, value);
        final sanitized = sanitizedValue is String
            ? sanitizedValue
            : stringify(sanitizedValue, maxLength: 200);
        pairs.add(
          '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(sanitized)}',
        );
      }
    }
    return pairs.join('&');
  }

  static String _decodePath(String path) {
    if (path.isEmpty || !path.contains('%')) return path;
    try {
      final parts = path.split('/');
      final decoded = parts
          .map(
            (segment) =>
                segment.isEmpty ? segment : Uri.decodeComponent(segment),
          )
          .toList(growable: false);
      return decoded.join('/');
    } catch (_) {
      return path;
    }
  }

  static String locationFingerprint({
    Object? latitude,
    Object? longitude,
    String? locationName,
  }) {
    final lat = latitude?.toString().trim() ?? '';
    final lng = longitude?.toString().trim() ?? '';
    final name = (locationName ?? '').trim();
    final seed = '$lat|$lng|$name';
    if (seed.replaceAll('|', '').isEmpty) return '';
    return _hashText(seed);
  }

  static String _sanitizePathKeyValue(String key, String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (key == 'filename' || key == 'file') {
      return _sanitizeFileValue(s);
    }
    if (_looksLikePathLikeValue(s) || _looksLikeFilenameValue(s)) {
      return redactPathLike(s);
    }
    return sanitizeText(s);
  }

  static String _sanitizeFileValue(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (_looksLikePathLikeValue(s)) {
      return redactPathLike(s);
    }
    if (_looksLikeFilenameValue(s)) {
      return redactWithFingerprint(s, kind: 'file');
    }
    return sanitizeText(s);
  }

  static String _sanitizeSourceValue(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (_looksLikePathLikeValue(s) || _looksLikeUrlLikeValue(s)) {
      return redactWithFingerprint(s, kind: 'source');
    }
    if (_looksLikeSensitiveCompositeValue(s)) {
      return redactWithFingerprint(s, kind: 'source');
    }
    return sanitizeText(s);
  }

  static String _sanitizeEntryValue(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (_looksLikeSensitiveCompositeValue(s) || _looksLikePathLikeValue(s)) {
      return redactWithFingerprint(s, kind: 'entry');
    }
    return sanitizeText(s);
  }

  static bool _looksLikeSensitiveCompositeValue(String value) {
    final parts = value
        .split('|')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length < 2) return false;
    return parts.any(_looksLikePathLikeValue) ||
        parts.any(_looksLikeUrlLikeValue) ||
        parts.any(_looksLikeWorkspaceKeyText);
  }

  static bool _looksLikeWorkspaceKeyText(String value) {
    final s = value.trim();
    if (!s.contains('|')) return false;
    return _workspaceKeyRegex.hasMatch(s);
  }

  static bool _looksLikeUrlLikeValue(String value) {
    final s = value.trim();
    if (s.isEmpty) return false;
    if (_fileUriRegex.hasMatch(s)) return true;
    final uri = Uri.tryParse(s);
    return uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty;
  }

  static bool _looksLikePathLikeValue(String value) {
    final s = value.trim();
    if (s.isEmpty) return false;
    return _windowsPathRegex.hasMatch(s) ||
        _uncPathRegex.hasMatch(s) ||
        _fileUriRegex.hasMatch(s) ||
        _debugPathPrefixRegex.hasMatch(s) ||
        s.startsWith('/');
  }

  static bool _looksLikeFilenameValue(String value) {
    final s = value.trim();
    if (s.isEmpty) return false;
    if (s.contains('/') || s.contains('\\')) return false;
    return _filenameRegex.hasMatch(s);
  }

  static String _semanticKindForKey(String key) {
    switch (key) {
      case 'query':
        return 'query';
      case 'title':
        return 'title';
      case 'subtitle':
        return 'subtitle';
      case 'city':
        return 'city';
      case 'reversegeocodelabel':
        return 'location';
      default:
        return 'text';
    }
  }

  static String _normalizeKey(String key) {
    return key.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String _normalizeKind(String kind) {
    final normalized = kind.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    if (normalized.isEmpty) return 'text';
    return normalized;
  }

  static String _hashText(String raw) {
    final bytes = utf8.encode(raw);
    var hash = 0x811C9DC5;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _maskValue(
    String raw, {
    required int keepStart,
    required int keepEnd,
  }) {
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
  static final RegExp _bearerRegex = RegExp(
    r'Bearer\s+([A-Za-z0-9\-\._=]+)',
    caseSensitive: false,
  );
  static final RegExp _tokenParamRegex = RegExp(
    r'(token|access_token|refresh_token|api[_-]?key|apikey|personalaccesstoken|personal_access_token|pat|auth|signature|sig|key|password|secret)=([^\s&]+)',
    caseSensitive: false,
  );
  static final RegExp _workspaceKeyRegex = RegExp(
    r'(?:https?:\/\/[^\s|]+|(?:localhost|[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[A-Za-z0-9.-]+:\d+)(?:\/[^\s|]*)?)\|[^\s|]+',
    caseSensitive: false,
  );
  static final RegExp _windowsPathRegex = RegExp(
    r'[A-Za-z]:\\[^\s<>:"|?*]+(?:\\[^\s<>:"|?*]+)*',
  );
  static final RegExp _uncPathRegex = RegExp(
    r'\\\\[^\s\\/:*?"<>|]+(?:\\[^\s\\/:*?"<>|]+)+',
  );
  static final RegExp _fileUriRegex = RegExp(
    r'(?:file|content):\/\/[^\s)]+',
    caseSensitive: false,
  );
  static final RegExp _debugPathPrefixRegex = RegExp(
    r'(?:tree|path):[^\s)]+',
    caseSensitive: false,
  );
  static final RegExp _coordinatePairRegex = RegExp(
    r'(?<!\d)-?\d{1,3}\.\d{4,}\s*,\s*-?\d{1,3}\.\d{4,}(?!\d)',
  );
  static final RegExp _urlRegex = RegExp(r'https?://[^\s)]+');
  static final RegExp _base64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
  static final RegExp _filenameRegex = RegExp(
    r'^[^\\/\r\n]+\.[A-Za-z0-9]{1,10}$',
  );
}
