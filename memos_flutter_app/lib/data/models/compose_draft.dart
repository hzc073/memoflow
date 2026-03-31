import 'dart:convert';

import 'memo_location.dart';
import '../../state/memos/memo_composer_state.dart';

class ComposeDraftAttachment {
  const ComposeDraftAttachment({
    required this.uid,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
    this.skipCompression = false,
    this.shareInlineImage = false,
    this.fromThirdPartyShare = false,
    this.sourceUrl,
  });

  final String uid;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
  final bool skipCompression;
  final bool shareInlineImage;
  final bool fromThirdPartyShare;
  final String? sourceUrl;

  factory ComposeDraftAttachment.fromPendingAttachment(
    MemoComposerPendingAttachment attachment,
  ) {
    return ComposeDraftAttachment(
      uid: attachment.uid,
      filePath: attachment.filePath,
      filename: attachment.filename,
      mimeType: attachment.mimeType,
      size: attachment.size,
      skipCompression: attachment.skipCompression,
      shareInlineImage: attachment.shareInlineImage,
      fromThirdPartyShare: attachment.fromThirdPartyShare,
      sourceUrl: attachment.sourceUrl,
    );
  }

  factory ComposeDraftAttachment.fromJson(Map<String, dynamic> json) {
    return ComposeDraftAttachment(
      uid: (json['uid'] as String? ?? '').trim(),
      filePath: (json['filePath'] as String? ?? '').trim(),
      filename: (json['filename'] as String? ?? '').trim(),
      mimeType: (json['mimeType'] as String? ?? '').trim(),
      size: _readInt(json['size']),
      skipCompression: _readBool(json['skipCompression']),
      shareInlineImage: _readBool(json['shareInlineImage']),
      fromThirdPartyShare: _readBool(json['fromThirdPartyShare']),
      sourceUrl: _readNullableString(json['sourceUrl']),
    );
  }

  MemoComposerPendingAttachment toPendingAttachment() {
    return MemoComposerPendingAttachment(
      uid: uid,
      filePath: filePath,
      filename: filename,
      mimeType: mimeType,
      size: size,
      skipCompression: skipCompression,
      shareInlineImage: shareInlineImage,
      fromThirdPartyShare: fromThirdPartyShare,
      sourceUrl: sourceUrl,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    'filePath': filePath,
    'filename': filename,
    'mimeType': mimeType,
    'size': size,
    'skipCompression': skipCompression,
    'shareInlineImage': shareInlineImage,
    'fromThirdPartyShare': fromThirdPartyShare,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
  };
}

class ComposeDraftSnapshot {
  const ComposeDraftSnapshot({
    required this.content,
    required this.visibility,
    this.relations = const <Map<String, dynamic>>[],
    this.attachments = const <ComposeDraftAttachment>[],
    this.location,
  });

  final String content;
  final String visibility;
  final List<Map<String, dynamic>> relations;
  final List<ComposeDraftAttachment> attachments;
  final MemoLocation? location;

  bool get hasSavableContent {
    return content.trim().isNotEmpty ||
        attachments.isNotEmpty ||
        relations.isNotEmpty ||
        location != null;
  }

  String get previewText {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isNotEmpty) return normalized;
    if (attachments.isNotEmpty) return '[${attachments.length} attachments]';
    if (relations.isNotEmpty) return '[${relations.length} linked memos]';
    if (location != null) return location!.displayText();
    return '';
  }

  ComposeDraftSnapshot copyWith({
    String? content,
    String? visibility,
    List<Map<String, dynamic>>? relations,
    List<ComposeDraftAttachment>? attachments,
    Object? location = _composeDraftNoChange,
  }) {
    return ComposeDraftSnapshot(
      content: content ?? this.content,
      visibility: visibility ?? this.visibility,
      relations: relations ?? this.relations,
      attachments: attachments ?? this.attachments,
      location: identical(location, _composeDraftNoChange)
          ? this.location
          : location as MemoLocation?,
    );
  }
}

class ComposeDraftRecord {
  const ComposeDraftRecord({
    required this.uid,
    required this.workspaceKey,
    required this.snapshot,
    required this.createdTime,
    required this.updatedTime,
  });

  final String uid;
  final String workspaceKey;
  final ComposeDraftSnapshot snapshot;
  final DateTime createdTime;
  final DateTime updatedTime;

  int get attachmentCount => snapshot.attachments.length;

  factory ComposeDraftRecord.fromRow(Map<String, dynamic> row) {
    return ComposeDraftRecord(
      uid: (row['uid'] as String? ?? '').trim(),
      workspaceKey: (row['workspace_key'] as String? ?? '').trim(),
      snapshot: ComposeDraftSnapshot(
        content: (row['content'] as String? ?? ''),
        visibility: (row['visibility'] as String? ?? 'PRIVATE').trim(),
        relations: _decodeRelations(row['relations_json']),
        attachments: _decodeAttachments(row['attachments_json']),
        location: _decodeLocation(row),
      ),
      createdTime: DateTime.fromMillisecondsSinceEpoch(
        _readInt(row['created_time']),
        isUtc: true,
      ),
      updatedTime: DateTime.fromMillisecondsSinceEpoch(
        _readInt(row['updated_time']),
        isUtc: true,
      ),
    );
  }

  Map<String, Object?> toRow() => <String, Object?>{
    'uid': uid,
    'workspace_key': workspaceKey,
    'content': snapshot.content,
    'visibility': snapshot.visibility,
    'relations_json': _encodeJsonArray(snapshot.relations),
    'attachments_json': _encodeJsonArray(
      snapshot.attachments.map((attachment) => attachment.toJson()).toList(),
    ),
    'location_placeholder': snapshot.location?.placeholder,
    'location_lat': snapshot.location?.latitude,
    'location_lng': snapshot.location?.longitude,
    'created_time': createdTime.toUtc().millisecondsSinceEpoch,
    'updated_time': updatedTime.toUtc().millisecondsSinceEpoch,
  };

  ComposeDraftRecord copyWith({
    String? uid,
    String? workspaceKey,
    ComposeDraftSnapshot? snapshot,
    DateTime? createdTime,
    DateTime? updatedTime,
  }) {
    return ComposeDraftRecord(
      uid: uid ?? this.uid,
      workspaceKey: workspaceKey ?? this.workspaceKey,
      snapshot: snapshot ?? this.snapshot,
      createdTime: createdTime ?? this.createdTime,
      updatedTime: updatedTime ?? this.updatedTime,
    );
  }

  static List<Map<String, dynamic>> _decodeRelations(Object? raw) {
    final decoded = _decodeJsonList(raw);
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
  }

  static List<ComposeDraftAttachment> _decodeAttachments(Object? raw) {
    final decoded = _decodeJsonList(raw);
    return decoded
        .whereType<Map>()
        .map(
          (item) =>
              ComposeDraftAttachment.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  static MemoLocation? _decodeLocation(Map<String, dynamic> row) {
    final lat = _readDouble(row['location_lat']);
    final lng = _readDouble(row['location_lng']);
    if (lat == null || lng == null) return null;
    return MemoLocation(
      placeholder: (row['location_placeholder'] as String? ?? ''),
      latitude: lat,
      longitude: lng,
    );
  }

  static List<dynamic> _decodeJsonList(Object? raw) {
    if (raw is List) return raw;
    if (raw is! String || raw.trim().isEmpty) return const <dynamic>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {}
    return const <dynamic>[];
  }

  static String _encodeJsonArray(List<dynamic> value) {
    return jsonEncode(value);
  }
}

const Object _composeDraftNoChange = Object();

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

double? _readDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  return false;
}

String? _readNullableString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
