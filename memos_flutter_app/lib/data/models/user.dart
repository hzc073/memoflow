class User {
  const User({
    required this.name,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  final String name;
  final String username;
  final String displayName;
  final String avatarUrl;

  const User.empty()
      : name = '',
        username = '',
        displayName = '',
        avatarUrl = '';

  factory User.fromJson(Map<String, dynamic> json) {
    final username = (json['username'] as String?) ?? (json['email'] as String?) ?? '';
    final avatarUrl = (json['avatarUrl'] as String?) ?? (json['avatar_url'] as String?) ?? '';
    final rawName = (json['name'] as String?) ?? '';
    final idRaw = json['id'] ?? json['userId'] ?? json['user_id'];
    final id = idRaw?.toString() ?? '';
    final rawNameTrimmed = rawName.trim();
    final idTrimmed = id.trim();
    final name = rawNameTrimmed.startsWith('users/')
        ? rawNameTrimmed
        : (rawNameTrimmed.contains('/') && rawNameTrimmed.split('/').last.isNotEmpty)
            ? rawNameTrimmed
            : idTrimmed.isNotEmpty
                ? 'users/$idTrimmed'
                : (int.tryParse(rawNameTrimmed) != null ? 'users/$rawNameTrimmed' : rawNameTrimmed);
    final displayNameCandidate = (json['displayName'] as String?) ??
        (json['display_name'] as String?) ??
        (json['nickname'] as String?) ??
        (rawName.trim().startsWith('users/') ? null : rawName.trim());
    final displayName = (displayNameCandidate != null && displayNameCandidate.trim().isNotEmpty)
        ? displayNameCandidate.trim()
        : username;

    return User(
      name: name,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      };
}
