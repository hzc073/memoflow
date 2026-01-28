import 'webdav_sync_meta.dart';

class WebDavSyncState {
  const WebDavSyncState({
    required this.lastSyncAt,
    required this.files,
  });

  final String? lastSyncAt;
  final Map<String, WebDavFileMeta> files;

  static const empty = WebDavSyncState(lastSyncAt: null, files: {});

  Map<String, dynamic> toJson() => {
        'lastSyncAt': lastSyncAt,
        'files': files.map((key, value) => MapEntry(key, value.toJson())),
      };

  factory WebDavSyncState.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    final files = <String, WebDavFileMeta>{};
    if (rawFiles is Map) {
      for (final entry in rawFiles.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is Map) {
          files[key] = WebDavFileMeta.fromJson(value.cast<String, dynamic>());
        }
      }
    }
    final lastSyncAt = json['lastSyncAt'] as String?;
    return WebDavSyncState(lastSyncAt: lastSyncAt, files: files);
  }
}
