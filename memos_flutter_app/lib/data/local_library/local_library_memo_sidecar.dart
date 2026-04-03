import 'dart:convert';

import '../../core/memo_relations.dart';
import '../models/attachment.dart';
import '../models/local_memo.dart';
import '../models/memo_location.dart';
import '../models/memo_relation.dart';

const int localLibraryMemoSidecarSchemaVersion = 1;

String memoSidecarRelativePath(String memoUid) {
  final trimmed = memoUid.trim();
  return 'memos/_meta/$trimmed.json';
}

class LocalLibraryAttachmentExportMeta {
  const LocalLibraryAttachmentExportMeta({
    required this.archiveName,
    required this.uid,
    required this.name,
    required this.filename,
    required this.type,
    required this.size,
    required this.externalLink,
  });

  final String archiveName;
  final String uid;
  final String name;
  final String filename;
  final String type;
  final int size;
  final String externalLink;

  factory LocalLibraryAttachmentExportMeta.fromAttachment({
    required Attachment attachment,
    required String archiveName,
  }) {
    return LocalLibraryAttachmentExportMeta(
      archiveName: archiveName,
      uid: attachment.uid,
      name: attachment.name,
      filename: attachment.filename,
      type: attachment.type,
      size: attachment.size,
      externalLink: attachment.externalLink,
    );
  }

  factory LocalLibraryAttachmentExportMeta.fromJson(Map<String, dynamic> json) {
    int readSize() {
      final raw = json['size'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? 0;
      return 0;
    }

    return LocalLibraryAttachmentExportMeta(
      archiveName: (json['archiveName'] as String?) ?? '',
      uid: (json['uid'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      filename: (json['filename'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      size: readSize(),
      externalLink: (json['externalLink'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'archiveName': archiveName,
      'uid': uid,
      'name': name,
      'filename': filename,
      'type': type,
      'size': size,
      'externalLink': externalLink,
    };
  }
}

class LocalLibraryMemoSidecar {
  const LocalLibraryMemoSidecar({
    required this.schemaVersion,
    required this.memoUid,
    required this.contentFingerprint,
    this.displayTime,
    this.location,
    this.relations = const <MemoRelation>[],
    this.attachments = const <LocalLibraryAttachmentExportMeta>[],
    this.relationCount,
    this.relationsComplete,
    this.hasDisplayTime = false,
    this.hasLocation = false,
    this.hasRelations = false,
    this.hasAttachments = false,
  });

  final int schemaVersion;
  final String memoUid;
  final String contentFingerprint;
  final DateTime? displayTime;
  final MemoLocation? location;
  final List<MemoRelation> relations;
  final List<LocalLibraryAttachmentExportMeta> attachments;
  final int? relationCount;
  final bool? relationsComplete;
  final bool hasDisplayTime;
  final bool hasLocation;
  final bool hasRelations;
  final bool hasAttachments;

  bool get hasRelationMetadata =>
      hasRelations || relationCount != null || relationsComplete != null;

  bool get relationsAreComplete => relationsComplete ?? hasRelations;

  int resolveRelationCount() {
    final explicitRelationCount = relationCount;
    if (explicitRelationCount != null) {
      return explicitRelationCount < 0 ? 0 : explicitRelationCount;
    }
    if (!hasRelations) return 0;
    return countReferenceRelations(memoUid: memoUid, relations: relations);
  }

  factory LocalLibraryMemoSidecar.fromMemo({
    required LocalMemo memo,
    required bool hasRelations,
    required List<MemoRelation> relations,
    required List<LocalLibraryAttachmentExportMeta> attachments,
    bool hasAttachments = true,
    int? relationCount,
    bool? relationsComplete,
  }) {
    return LocalLibraryMemoSidecar(
      schemaVersion: localLibraryMemoSidecarSchemaVersion,
      memoUid: memo.uid,
      contentFingerprint: memo.contentFingerprint,
      displayTime: memo.displayTime?.toUtc(),
      location: memo.location,
      relations: relations,
      attachments: attachments,
      relationCount: hasRelations
          ? (relationCount ?? memo.relationCount)
          : null,
      relationsComplete: hasRelations
          ? (relationsComplete ?? true)
          : relationsComplete,
      hasDisplayTime: true,
      hasLocation: true,
      hasRelations: hasRelations,
      hasAttachments: hasAttachments,
    );
  }

  factory LocalLibraryMemoSidecar.fromJson(Map<String, dynamic> json) {
    int readSchemaVersion() {
      final raw = json['schemaVersion'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? 1;
      return 1;
    }

    DateTime? readDisplayTime() {
      final raw = json['displayTime'];
      if (raw is String && raw.trim().isNotEmpty) {
        return DateTime.tryParse(raw.trim())?.toUtc();
      }
      return null;
    }

    MemoLocation? readLocation() {
      final raw = json['location'];
      if (raw is Map<String, dynamic>) {
        return MemoLocation.fromJson(raw);
      }
      if (raw is Map) {
        return MemoLocation.fromJson(raw.cast<String, dynamic>());
      }
      return null;
    }

    List<MemoRelation> readRelations() {
      final raw = json['relations'];
      if (raw is! List) return const <MemoRelation>[];
      return raw
          .whereType<Map>()
          .map((item) => MemoRelation.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
    }

    List<LocalLibraryAttachmentExportMeta> readAttachments() {
      final raw = json['attachments'];
      if (raw is! List) return const <LocalLibraryAttachmentExportMeta>[];
      return raw
          .whereType<Map>()
          .map(
            (item) => LocalLibraryAttachmentExportMeta.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false);
    }

    int? readOptionalInt(String key) {
      if (!json.containsKey(key)) return null;
      final raw = json[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim());
      return null;
    }

    bool? readOptionalBool(String key) {
      if (!json.containsKey(key)) return null;
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return null;
    }

    return LocalLibraryMemoSidecar(
      schemaVersion: readSchemaVersion(),
      memoUid: (json['memoUid'] as String?) ?? '',
      contentFingerprint: (json['contentFingerprint'] as String?) ?? '',
      displayTime: readDisplayTime(),
      location: readLocation(),
      relations: readRelations(),
      attachments: readAttachments(),
      relationCount: readOptionalInt('relationCount'),
      relationsComplete: readOptionalBool('relationsComplete'),
      hasDisplayTime: json.containsKey('displayTime'),
      hasLocation: json.containsKey('location'),
      hasRelations: json.containsKey('relations'),
      hasAttachments: json.containsKey('attachments'),
    );
  }

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'memoUid': memoUid,
      'contentFingerprint': contentFingerprint,
    };
    if (hasDisplayTime) {
      payload['displayTime'] = displayTime?.toUtc().toIso8601String();
    }
    if (hasLocation) {
      payload['location'] = location?.toJson();
    }
    if (hasRelations) {
      payload['relations'] = relations
          .map((relation) => relation.toJson())
          .toList(growable: false);
    }
    if (relationCount != null) {
      payload['relationCount'] = relationCount;
    }
    if (relationsComplete != null) {
      payload['relationsComplete'] = relationsComplete;
    }
    if (hasAttachments) {
      payload['attachments'] = attachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false);
    }
    return payload;
  }

  String encodeJson() => jsonEncode(toJson());

  static LocalLibraryMemoSidecar? tryParse(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return LocalLibraryMemoSidecar.fromJson(decoded);
      }
      if (decoded is Map) {
        return LocalLibraryMemoSidecar.fromJson(
          decoded.cast<String, dynamic>(),
        );
      }
    } catch (_) {}
    return null;
  }
}
