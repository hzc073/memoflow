import '../models/attachment.dart';

String sanitizePathSegment(String raw, {String fallback = 'attachment'}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return fallback;
  return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

String memoFilename(String uid) {
  final trimmed = uid.trim();
  if (trimmed.isEmpty) return 'memo.md';
  return '$trimmed.md';
}

String attachmentArchiveName(Attachment attachment) {
  final rawName = attachment.filename.trim().isNotEmpty
      ? attachment.filename.trim()
      : (attachment.uid.isNotEmpty ? attachment.uid : attachment.name);
  final safeName = sanitizePathSegment(rawName, fallback: 'attachment');
  final uid = attachment.uid.trim();
  if (uid.isEmpty) return safeName;
  if (safeName.startsWith('$uid.')) return safeName;
  if (safeName == uid) return safeName;
  return '${uid}_$safeName';
}

String attachmentArchiveNameFromPayload({
  required String attachmentUid,
  required String filename,
}) {
  final rawName = filename.trim().isNotEmpty ? filename.trim() : attachmentUid.trim();
  final safeName = sanitizePathSegment(rawName, fallback: 'attachment');
  final uid = attachmentUid.trim();
  if (uid.isEmpty) return safeName;
  if (safeName.startsWith('$uid.')) return safeName;
  if (safeName == uid) return safeName;
  return '${uid}_$safeName';
}

String? parseAttachmentUidFromFilename(String filename) {
  final trimmed = filename.trim();
  if (trimmed.isEmpty) return null;
  final idx = trimmed.indexOf('_');
  if (idx <= 0) return null;
  final uid = trimmed.substring(0, idx).trim();
  return uid.isEmpty ? null : uid;
}

String stripAttachmentUidPrefix(String filename, String uid) {
  final trimmed = filename.trim();
  final prefix = '${uid}_';
  if (trimmed.startsWith(prefix)) {
    return trimmed.substring(prefix.length);
  }
  return trimmed;
}
