String normalizeWebDavBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) return trimmed;
  var path = parsed.path;
  while (path.endsWith('/') && path.length > 1) {
    path = path.substring(0, path.length - 1);
  }
  return parsed.replace(path: path).toString();
}

String normalizeWebDavRootPath(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return WebDavDefaults.rootPath;
  var path = trimmed;
  if (!path.startsWith('/')) {
    path = '/$path';
  }
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

Uri joinWebDavUri({
  required Uri baseUrl,
  required String rootPath,
  required String relativePath,
}) {
  final base = _trimSlashes(baseUrl.path);
  final root = _trimSlashes(rootPath);
  final rel = _trimSlashes(relativePath);
  final segments = <String>[
    if (base.isNotEmpty) base,
    if (root.isNotEmpty) root,
    if (rel.isNotEmpty) rel,
  ];
  final path = '/${segments.join('/')}';
  return baseUrl.replace(path: path);
}

String _trimSlashes(String value) {
  var out = value;
  while (out.startsWith('/')) {
    out = out.substring(1);
  }
  while (out.endsWith('/')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

class WebDavDefaults {
  static const rootPath = '/MemoFlow/settings/v1';
}
