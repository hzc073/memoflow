class Shortcut {
  const Shortcut({
    required this.name,
    required this.id,
    required this.title,
    required this.filter,
  });

  final String name;
  final String id;
  final String title;
  final String filter;

  String get shortcutId {
    if (id.trim().isNotEmpty) return id.trim();
    return _lastSegment(name);
  }

  factory Shortcut.fromJson(Map<String, dynamic> json) {
    final name = _readString(json['name']);
    final id = _readString(json['id']);
    final resolvedId = id.isNotEmpty ? id : _lastSegment(name);
    return Shortcut(
      name: name,
      id: resolvedId,
      title: _readString(json['title']),
      filter: _readString(json['filter']),
    );
  }

  Shortcut copyWith({
    String? name,
    String? id,
    String? title,
    String? filter,
  }) {
    return Shortcut(
      name: name ?? this.name,
      id: id ?? this.id,
      title: title ?? this.title,
      filter: filter ?? this.filter,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'title': title,
      'filter': filter,
    };
    if (name.trim().isNotEmpty) {
      data['name'] = name.trim();
    }
    if (id.trim().isNotEmpty) {
      data['id'] = id.trim();
    }
    return data;
  }
}

String _readString(dynamic value) {
  if (value is String) return value.trim();
  if (value == null) return '';
  return value.toString().trim();
}

String _lastSegment(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (!trimmed.contains('/')) return trimmed;
  final parts = trimmed.split('/');
  return parts.isEmpty ? '' : parts.last.trim();
}
