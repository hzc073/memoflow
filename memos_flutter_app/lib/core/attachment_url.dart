import '../data/models/attachment.dart';
import 'url.dart';

String normalizeAttachmentRemoteLink(Attachment attachment) {
  final link = attachment.externalLink.trim();
  final filename = attachment.filename.trim();
  if (link.isEmpty || filename.isEmpty) return link;

  final uri = Uri.tryParse(link);
  if (uri == null) return link;

  final segments = uri.pathSegments;
  if (segments.length != 3 || segments[0] != 'file') {
    return link;
  }
  final kind = segments[1];
  if (kind != 'resources' && kind != 'attachments') {
    return link;
  }

  final repaired = uri
      .replace(pathSegments: [...segments, filename])
      .toString();
  if (link.startsWith('/') && !repaired.startsWith('/')) {
    return '/$repaired';
  }
  return repaired;
}

String? resolveAttachmentRemoteUrl(Uri? baseUrl, Attachment attachment) {
  final link = normalizeAttachmentRemoteLink(attachment);
  if (link.isNotEmpty &&
      !link.startsWith('file://') &&
      !link.startsWith('content://')) {
    return resolveMaybeRelativeUrl(baseUrl, link);
  }

  if (baseUrl == null) return null;

  final name = attachment.name.trim();
  if (name.isEmpty) return null;

  final filename = attachment.filename.trim();
  final relativePath = filename.isEmpty ? 'file/$name' : 'file/$name/$filename';
  return joinBaseUrl(baseUrl, relativePath);
}
