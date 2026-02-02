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
