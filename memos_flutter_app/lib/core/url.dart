import 'dart:convert';
import 'dart:typed_data';

String canonicalBaseUrlString(Uri baseUrl) {
  final s = baseUrl.toString().trim();
  if (s.isEmpty) return s;
  return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

Uri sanitizeUserBaseUrl(Uri baseUrl) {
  final raw = baseUrl.toString().trim();
  if (raw.isEmpty) return baseUrl;

  final uri = Uri.parse(raw);
  var path = uri.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  final lower = path.toLowerCase();
  int cut = -1;
  final apiSegmentIndex = lower.indexOf('/api/');
  if (apiSegmentIndex >= 0) {
    cut = apiSegmentIndex;
  } else {
    for (final marker in const ['/api/v1', '/api/v2', '/api']) {
      final index = lower.indexOf(marker);
      if (index >= 0) {
        cut = index;
        break;
      }
    }
  }

  if (cut >= 0) {
    path = path.substring(0, cut);
  }

  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  );
}

String dioBaseUrlString(Uri baseUrl) => '${canonicalBaseUrlString(baseUrl)}/';

String joinBaseUrl(Uri baseUrl, String path) {
  final base = canonicalBaseUrlString(baseUrl);
  final p = path.startsWith('/') ? path.substring(1) : path;
  return '$base/$p';
}

bool isAbsoluteUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  return uri.hasScheme;
}

String resolveMaybeRelativeUrl(Uri? baseUrl, String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.hasScheme) return trimmed;
  if (baseUrl == null) return trimmed;
  return joinBaseUrl(baseUrl, trimmed);
}

bool isServerVersion024(String? versionRaw) {
  final trimmed = (versionRaw ?? '').trim();
  if (trimmed.isEmpty) return false;
  final match = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(trimmed);
  if (match == null) return false;
  final major = int.tryParse(match.group(1) ?? '');
  final minor = int.tryParse(match.group(2) ?? '');
  if (major == null || minor == null) return false;
  return major == 0 && minor == 24;
}

bool isServerVersion021(String? versionRaw) {
  final trimmed = (versionRaw ?? '').trim();
  if (trimmed.isEmpty) return false;
  final match = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(trimmed);
  if (match == null) return false;
  final major = int.tryParse(match.group(1) ?? '');
  final minor = int.tryParse(match.group(2) ?? '');
  if (major == null || minor == null) return false;
  return major == 0 && minor == 21;
}

int _effectivePort(Uri uri) {
  if (uri.hasPort) return uri.port;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') return 443;
  if (scheme == 'http') return 80;
  return -1;
}

bool isSameOriginUri(Uri a, Uri b) {
  final schemeA = a.scheme.toLowerCase();
  final schemeB = b.scheme.toLowerCase();
  if (schemeA != schemeB) return false;
  if (a.host.toLowerCase() != b.host.toLowerCase()) return false;
  return _effectivePort(a) == _effectivePort(b);
}

bool isSameOriginWithBase(Uri? baseUrl, String rawUrl) {
  if (baseUrl == null) return false;
  final parsed = Uri.tryParse(rawUrl.trim());
  if (parsed == null || !parsed.hasScheme) return false;
  return isSameOriginUri(baseUrl, parsed);
}

String? rebaseAbsoluteFileUrlToBase(Uri? baseUrl, String rawUrl) {
  if (baseUrl == null) return null;
  final parsed = Uri.tryParse(rawUrl.trim());
  if (parsed == null || !parsed.hasScheme) return null;
  final path = parsed.path;
  if (!(path.startsWith('/file/') || path.startsWith('file/'))) {
    return null;
  }
  var nextPath = path;
  if (parsed.hasQuery && parsed.query.isNotEmpty) {
    nextPath = '$nextPath?${parsed.query}';
  }
  return joinBaseUrl(baseUrl, nextPath);
}

String appendThumbnailParam(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return trimmed;
  final params = Map<String, String>.from(uri.queryParameters);
  if (params.containsKey('thumbnail')) return trimmed;
  final path = uri.path;
  final isLegacyResource = path.contains('/o/r/') || path.startsWith('o/r/');
  var useNumeric = isLegacyResource;
  if (!useNumeric) {
    final segments = uri.pathSegments;
    if (segments.length == 3 &&
        segments[0] == 'file' &&
        segments[1] == 'resources') {
      useNumeric = true;
    }
  }
  params['thumbnail'] = useNumeric ? '1' : 'true';
  return uri.replace(queryParameters: params).toString();
}

bool isDataUrl(String raw) {
  final trimmed = raw.trim();
  return trimmed.startsWith('data:');
}

Uint8List? tryDecodeDataUri(String raw) {
  final trimmed = raw.trim();
  if (!trimmed.startsWith('data:')) return null;
  final commaIndex = trimmed.indexOf(',');
  if (commaIndex <= 0 || commaIndex >= trimmed.length - 1) return null;
  final header = trimmed.substring(0, commaIndex).toLowerCase();
  if (!header.contains(';base64')) return null;
  final payload = trimmed.substring(commaIndex + 1).trim();
  if (payload.isEmpty) return null;
  try {
    return base64Decode(payload);
  } catch (_) {
    return null;
  }
}
