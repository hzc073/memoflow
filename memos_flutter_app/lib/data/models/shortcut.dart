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
    final rawId = id.trim();
    if (rawId.isNotEmpty) return rawId;
    final rawName = name.trim();
    if (rawName.isEmpty) return '';
    if (rawName.contains('/')) return rawName.split('/').last;
    return rawName;
  }

  factory Shortcut.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    return Shortcut(
      name: (json['name'] as String?) ?? '',
      id: idRaw == null ? '' : idRaw.toString(),
      title: (json['title'] as String?) ?? '',
      filter: (json['filter'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'id': id,
        'title': title,
        'filter': filter,
      };
}
