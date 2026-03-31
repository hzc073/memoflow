import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/models/compose_draft.dart';
import '../../data/models/memo_location.dart';
import '../attachments/queued_attachment_stager.dart';

const composeDraftTransferSchemaVersion = 1;
const composeDraftTransferConfigPath = 'config/draft_box.json';
const composeDraftTransferAttachmentsDir = 'drafts/attachments';

class ComposeDraftTransferBundle {
  const ComposeDraftTransferBundle({
    required this.drafts,
    this.schemaVersion = composeDraftTransferSchemaVersion,
    this.mergeWithExistingOnRestore = false,
  });

  final int schemaVersion;
  final List<ComposeDraftTransferRecord> drafts;
  final bool mergeWithExistingOnRestore;

  int get draftCount => drafts.length;
  int get draftAttachmentCount =>
      drafts.fold<int>(0, (sum, draft) => sum + draft.attachments.length);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'drafts': drafts.map((draft) => draft.toJson()).toList(growable: false),
  };

  factory ComposeDraftTransferBundle.fromJson(Map<String, dynamic> json) {
    final rawDrafts = json['drafts'];
    final drafts = rawDrafts is List
        ? rawDrafts
              .whereType<Map>()
              .map(
                (item) => ComposeDraftTransferRecord.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
        : const <ComposeDraftTransferRecord>[];
    return ComposeDraftTransferBundle(
      schemaVersion: _readInt(
        json['schemaVersion'],
        fallback: composeDraftTransferSchemaVersion,
      ),
      drafts: drafts,
    );
  }

  factory ComposeDraftTransferBundle.fromDraftRecords(
    Iterable<ComposeDraftRecord> drafts,
  ) {
    return ComposeDraftTransferBundle(
      drafts: drafts
          .map(ComposeDraftTransferRecord.fromDraftRecord)
          .toList(growable: false),
    );
  }

  factory ComposeDraftTransferBundle.fromLegacyNoteDraft(String text) {
    final now = DateTime.now().toUtc();
    return ComposeDraftTransferBundle(
      mergeWithExistingOnRestore: true,
      drafts: <ComposeDraftTransferRecord>[
        ComposeDraftTransferRecord(
          uid: 'legacy_note_draft',
          content: text,
          visibility: 'PRIVATE',
          relations: const <Map<String, dynamic>>[],
          attachments: const <ComposeDraftTransferAttachment>[],
          createdTime: now,
          updatedTime: now,
        ),
      ],
    );
  }
}

List<ComposeDraftRecord> mergeComposeDraftRecords({
  required Iterable<ComposeDraftRecord> existing,
  required Iterable<ComposeDraftRecord> incoming,
  required String workspaceKey,
}) {
  final mergedByUid = <String, ComposeDraftRecord>{};

  for (final draft in existing) {
    final uid = draft.uid.trim();
    if (uid.isEmpty) continue;
    mergedByUid[uid] = draft.copyWith(workspaceKey: workspaceKey);
  }

  for (final draft in incoming) {
    final uid = draft.uid.trim();
    if (uid.isEmpty) continue;
    mergedByUid[uid] = draft.copyWith(workspaceKey: workspaceKey);
  }

  final merged = mergedByUid.values.toList(growable: false);
  merged.sort((a, b) => b.updatedTime.compareTo(a.updatedTime));
  return merged;
}

class ComposeDraftTransferRecord {
  const ComposeDraftTransferRecord({
    required this.uid,
    required this.content,
    required this.visibility,
    required this.relations,
    required this.attachments,
    required this.createdTime,
    required this.updatedTime,
    this.location,
  });

  final String uid;
  final String content;
  final String visibility;
  final List<Map<String, dynamic>> relations;
  final List<ComposeDraftTransferAttachment> attachments;
  final MemoLocation? location;
  final DateTime createdTime;
  final DateTime updatedTime;

  factory ComposeDraftTransferRecord.fromJson(Map<String, dynamic> json) {
    final rawRelations = json['relations'];
    final rawAttachments = json['attachments'];
    return ComposeDraftTransferRecord(
      uid: (json['uid'] as String? ?? '').trim(),
      content: (json['content'] as String? ?? ''),
      visibility: (json['visibility'] as String? ?? 'PRIVATE').trim(),
      relations: rawRelations is List
          ? rawRelations
                .whereType<Map>()
                .map((item) => item.cast<String, dynamic>())
                .toList(growable: false)
          : const <Map<String, dynamic>>[],
      attachments: rawAttachments is List
          ? rawAttachments
                .whereType<Map>()
                .map(
                  (item) => ComposeDraftTransferAttachment.fromJson(
                    item.cast<String, dynamic>(),
                  ),
                )
                .toList(growable: false)
          : const <ComposeDraftTransferAttachment>[],
      location: _readLocation(json['location']),
      createdTime: DateTime.fromMillisecondsSinceEpoch(
        _readInt(json['createdTime']),
        isUtc: true,
      ),
      updatedTime: DateTime.fromMillisecondsSinceEpoch(
        _readInt(json['updatedTime']),
        isUtc: true,
      ),
    );
  }

  factory ComposeDraftTransferRecord.fromDraftRecord(
    ComposeDraftRecord record,
  ) {
    return ComposeDraftTransferRecord(
      uid: record.uid,
      content: record.snapshot.content,
      visibility: record.snapshot.visibility,
      relations: record.snapshot.relations,
      attachments: record.snapshot.attachments
          .map(
            (attachment) => ComposeDraftTransferAttachment.fromDraftAttachment(
              draftUid: record.uid,
              attachment: attachment,
            ),
          )
          .toList(growable: false),
      location: record.snapshot.location,
      createdTime: record.createdTime,
      updatedTime: record.updatedTime,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    'content': content,
    'visibility': visibility,
    'relations': relations,
    'attachments': attachments
        .map((attachment) => attachment.toJson())
        .toList(growable: false),
    if (location != null) 'location': location!.toJson(),
    'createdTime': createdTime.toUtc().millisecondsSinceEpoch,
    'updatedTime': updatedTime.toUtc().millisecondsSinceEpoch,
  };
}

class ComposeDraftTransferAttachment {
  const ComposeDraftTransferAttachment({
    required this.uid,
    required this.path,
    required this.filename,
    required this.mimeType,
    required this.size,
    this.skipCompression = false,
    this.shareInlineImage = false,
    this.fromThirdPartyShare = false,
    this.sourceUrl,
    this.sourceFilePath,
  });

  final String uid;
  final String path;
  final String filename;
  final String mimeType;
  final int size;
  final bool skipCompression;
  final bool shareInlineImage;
  final bool fromThirdPartyShare;
  final String? sourceUrl;
  final String? sourceFilePath;

  factory ComposeDraftTransferAttachment.fromJson(Map<String, dynamic> json) {
    return ComposeDraftTransferAttachment(
      uid: (json['uid'] as String? ?? '').trim(),
      path: (json['path'] as String? ?? '').trim(),
      filename: (json['filename'] as String? ?? '').trim(),
      mimeType: (json['mimeType'] as String? ?? '').trim(),
      size: _readInt(json['size']),
      skipCompression: _readBool(json['skipCompression']),
      shareInlineImage: _readBool(json['shareInlineImage']),
      fromThirdPartyShare: _readBool(json['fromThirdPartyShare']),
      sourceUrl: _readNullableString(json['sourceUrl']),
    );
  }

  factory ComposeDraftTransferAttachment.fromDraftAttachment({
    required String draftUid,
    required ComposeDraftAttachment attachment,
  }) {
    return ComposeDraftTransferAttachment(
      uid: attachment.uid,
      path: buildComposeDraftTransferAttachmentPath(
        draftUid: draftUid,
        attachmentUid: attachment.uid,
        filename: attachment.filename,
      ),
      filename: attachment.filename,
      mimeType: attachment.mimeType,
      size: attachment.size,
      skipCompression: attachment.skipCompression,
      shareInlineImage: attachment.shareInlineImage,
      fromThirdPartyShare: attachment.fromThirdPartyShare,
      sourceUrl: attachment.sourceUrl,
      sourceFilePath: attachment.filePath,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    'path': path,
    'filename': filename,
    'mimeType': mimeType,
    'size': size,
    'skipCompression': skipCompression,
    'shareInlineImage': shareInlineImage,
    'fromThirdPartyShare': fromThirdPartyShare,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
  };
}

String buildComposeDraftTransferAttachmentPath({
  required String draftUid,
  required String attachmentUid,
  required String filename,
}) {
  final safeFilename = filename.replaceAll(
    RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
    '_',
  );
  return '$composeDraftTransferAttachmentsDir/$draftUid/'
      '${attachmentUid}_$safeFilename';
}

Future<List<ComposeDraftRecord>> materializeComposeDraftTransferBundle({
  required ComposeDraftTransferBundle bundle,
  required Directory? rootDirectory,
  required String workspaceKey,
  required QueuedAttachmentStager attachmentStager,
}) async {
  final records = <ComposeDraftRecord>[];
  for (final draft in bundle.drafts) {
    final attachments = <ComposeDraftAttachment>[];
    for (final attachment in draft.attachments) {
      final relativePath = attachment.path.replaceAll('\\', '/').trim();
      if (relativePath.isEmpty) {
        throw const FormatException('Draft attachment path missing');
      }
      final attachmentRootDirectory = rootDirectory;
      if (attachmentRootDirectory == null) {
        throw const FormatException('Draft attachment root missing');
      }
      final sourceFile = File(
        p.joinAll(<String>[
          attachmentRootDirectory.path,
          ...p.split(relativePath),
        ]),
      );
      if (!await sourceFile.exists()) {
        throw FileSystemException(
          'Draft attachment file not found',
          sourceFile.path,
        );
      }
      final staged = await attachmentStager.stageDraftAttachment(
        uid: attachment.uid,
        filePath: sourceFile.path,
        filename: attachment.filename,
        mimeType: attachment.mimeType,
        size: attachment.size,
        scopeKey: workspaceKey,
      );
      attachments.add(
        ComposeDraftAttachment(
          uid: attachment.uid,
          filePath: staged.filePath,
          filename: staged.filename,
          mimeType: staged.mimeType,
          size: staged.size,
          skipCompression: attachment.skipCompression,
          shareInlineImage: attachment.shareInlineImage,
          fromThirdPartyShare: attachment.fromThirdPartyShare,
          sourceUrl: attachment.sourceUrl,
        ),
      );
    }
    records.add(
      ComposeDraftRecord(
        uid: draft.uid,
        workspaceKey: workspaceKey,
        snapshot: ComposeDraftSnapshot(
          content: draft.content,
          visibility: draft.visibility,
          relations: draft.relations,
          attachments: attachments,
          location: draft.location,
        ),
        createdTime: draft.createdTime,
        updatedTime: draft.updatedTime,
      ),
    );
  }
  return records;
}

MemoLocation? _readLocation(Object? raw) {
  if (raw is Map<String, dynamic>) return MemoLocation.fromJson(raw);
  if (raw is Map) return MemoLocation.fromJson(raw.cast<String, dynamic>());
  return null;
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
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
