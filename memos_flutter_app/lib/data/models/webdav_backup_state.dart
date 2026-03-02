class WebDavBackupState {
  const WebDavBackupState({
    required this.lastBackupAt,
    required this.lastSnapshotId,
    required this.lastExportSuccessAt,
    required this.lastUploadSuccessAt,
    required this.exportPlainDetectedAt,
    required this.exportPlainRemindAfter,
    required this.exportPlainClearedAt,
  });

  final String? lastBackupAt;
  final String? lastSnapshotId;
  final String? lastExportSuccessAt;
  final String? lastUploadSuccessAt;
  final String? exportPlainDetectedAt;
  final String? exportPlainRemindAfter;
  final String? exportPlainClearedAt;

  static const empty = WebDavBackupState(
    lastBackupAt: null,
    lastSnapshotId: null,
    lastExportSuccessAt: null,
    lastUploadSuccessAt: null,
    exportPlainDetectedAt: null,
    exportPlainRemindAfter: null,
    exportPlainClearedAt: null,
  );

  WebDavBackupState copyWith({
    String? lastBackupAt,
    String? lastSnapshotId,
    String? lastExportSuccessAt,
    String? lastUploadSuccessAt,
    String? exportPlainDetectedAt,
    String? exportPlainRemindAfter,
    String? exportPlainClearedAt,
  }) {
    return WebDavBackupState(
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      lastSnapshotId: lastSnapshotId ?? this.lastSnapshotId,
      lastExportSuccessAt:
          lastExportSuccessAt ?? this.lastExportSuccessAt,
      lastUploadSuccessAt:
          lastUploadSuccessAt ?? this.lastUploadSuccessAt,
      exportPlainDetectedAt:
          exportPlainDetectedAt ?? this.exportPlainDetectedAt,
      exportPlainRemindAfter:
          exportPlainRemindAfter ?? this.exportPlainRemindAfter,
      exportPlainClearedAt:
          exportPlainClearedAt ?? this.exportPlainClearedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    if (lastBackupAt != null) 'lastBackupAt': lastBackupAt,
    if (lastSnapshotId != null) 'lastSnapshotId': lastSnapshotId,
    if (lastExportSuccessAt != null)
      'lastExportSuccessAt': lastExportSuccessAt,
    if (lastUploadSuccessAt != null)
      'lastUploadSuccessAt': lastUploadSuccessAt,
    if (exportPlainDetectedAt != null)
      'exportPlainDetectedAt': exportPlainDetectedAt,
    if (exportPlainRemindAfter != null)
      'exportPlainRemindAfter': exportPlainRemindAfter,
    if (exportPlainClearedAt != null)
      'exportPlainClearedAt': exportPlainClearedAt,
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
      lastExportSuccessAt: readString('lastExportSuccessAt'),
      lastUploadSuccessAt: readString('lastUploadSuccessAt'),
      exportPlainDetectedAt: readString('exportPlainDetectedAt'),
      exportPlainRemindAfter: readString('exportPlainRemindAfter'),
      exportPlainClearedAt: readString('exportPlainClearedAt'),
    );
  }
}
