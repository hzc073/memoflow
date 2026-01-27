import 'url.dart';

Uri sanitizeImageBedBaseUrl(Uri baseUrl) {
  var s = baseUrl.toString().trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  final lower = s.toLowerCase();
  if (lower.endsWith('/api/v1')) {
    s = s.substring(0, s.length - '/api/v1'.length);
  } else if (lower.endsWith('/api/v2')) {
    s = s.substring(0, s.length - '/api/v2'.length);
  }
  return Uri.parse(s);
}

String imageBedLegacyApiBase(Uri baseUrl) {
  final base = canonicalBaseUrlString(baseUrl);
  return '$base/api/v1';
}

String imageBedModernApiBase(Uri baseUrl) {
  final base = canonicalBaseUrlString(baseUrl);
  return '$base/api/v2';
}
