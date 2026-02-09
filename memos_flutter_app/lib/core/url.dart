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
    if (segments.length == 3 && segments[0] == 'file' && segments[1] == 'resources') {
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
