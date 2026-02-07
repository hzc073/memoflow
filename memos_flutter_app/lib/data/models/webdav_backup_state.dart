class WebDavBackupState {
  const WebDavBackupState({
    required this.lastBackupAt,
    required this.lastSnapshotId,
  });

  final String? lastBackupAt;
  final String? lastSnapshotId;

  static const empty = WebDavBackupState(
    lastBackupAt: null,
    lastSnapshotId: null,
  );

  WebDavBackupState copyWith({String? lastBackupAt, String? lastSnapshotId}) {
    return WebDavBackupState(
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      lastSnapshotId: lastSnapshotId ?? this.lastSnapshotId,
    );
  }

  Map<String, dynamic> toJson() => {
    if (lastBackupAt != null) 'lastBackupAt': lastBackupAt,
    if (lastSnapshotId != null) 'lastSnapshotId': lastSnapshotId,
  };

  factory WebDavBackupState.fromJson(Map<String, dynamic> json) {
    String? readString(String key) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw;
      return null;
    }

    return WebDavBackupState(
      lastBackupAt: readString('lastBackupAt'),
      lastSnapshotId: readString('lastSnapshotId'),
    );
  }
}
