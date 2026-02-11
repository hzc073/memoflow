bool mimeTypeIsSvg(String? mimeType) {
  final normalized = (mimeType ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return false;
  return normalized.contains('image/svg+xml') || normalized.endsWith('/svg+xml');
}

bool looksLikeSvgUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return trimmed.toLowerCase().contains('.svg');
  }
  final path = uri.path.toLowerCase();
  if (path.endsWith('.svg')) return true;
  final query = uri.query.toLowerCase();
  if (query.contains('format=svg')) return true;
  if (query.contains('mime=image/svg+xml')) return true;
  return false;
}

bool shouldUseSvgRenderer({String url = '', String? mimeType}) {
  return mimeTypeIsSvg(mimeType) || looksLikeSvgUrl(url);
}
