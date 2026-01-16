class PersonalAccessToken {
  const PersonalAccessToken({
    required this.name,
    required this.description,
    required this.createdAt,
    required this.expiresAt,
    required this.lastUsedAt,
  });

  final String name;
  final String description;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;

  String get id => name.contains('/') ? name.split('/').last : name;

  factory PersonalAccessToken.fromJson(Map<String, dynamic> json) {
    return PersonalAccessToken(
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      createdAt: _parseTime(json['createdAt'] ?? json['created_at']),
      expiresAt: _parseTime(json['expiresAt'] ?? json['expires_at']),
      lastUsedAt: _parseTime(json['lastUsedAt'] ?? json['last_used_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'lastUsedAt': lastUsedAt?.toUtc().toIso8601String(),
      };

  static DateTime? _parseTime(dynamic v) {
    if (v is String && v.trim().isNotEmpty) {
      return DateTime.tryParse(v.trim());
    }
    return null;
  }
}

