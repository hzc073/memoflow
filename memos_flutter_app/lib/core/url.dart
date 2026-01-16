String canonicalBaseUrlString(Uri baseUrl) {
  final s = baseUrl.toString().trim();
  if (s.isEmpty) return s;
  return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

Uri sanitizeUserBaseUrl(Uri baseUrl) {
  var s = baseUrl.toString().trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.toLowerCase().endsWith('/api/v1')) {
    s = s.substring(0, s.length - '/api/v1'.length);
  }
  return Uri.parse(s);
}

String dioBaseUrlString(Uri baseUrl) => '${canonicalBaseUrlString(baseUrl)}/';

String joinBaseUrl(Uri baseUrl, String path) {
  final base = canonicalBaseUrlString(baseUrl);
  final p = path.startsWith('/') ? path.substring(1) : path;
  return '$base/$p';
}
