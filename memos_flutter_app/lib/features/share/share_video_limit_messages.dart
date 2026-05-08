import '../../i18n/strings.g.dart';

String formatShareVideoSizeLabel(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1)} MB';
}

String shareVideoAttachmentTooLargeTitle(
  Translations translations,
  int maxBytes,
) {
  return translations.strings.shareClip.fileTooLargeTitle(
    limit: formatShareVideoSizeLabel(maxBytes),
  );
}

String shareVideoAttachmentTooLargeBody(
  Translations translations, {
  required int fileSizeBytes,
  required int maxBytes,
}) {
  return translations.strings.shareClip.fileTooLargeBody(
    size: formatShareVideoSizeLabel(fileSizeBytes),
    limit: formatShareVideoSizeLabel(maxBytes),
  );
}

String shareVideoAttachmentStillTooLargeMessage(
  Translations translations, {
  required int? maxBytes,
}) {
  if (maxBytes == null || maxBytes <= 0) {
    return translations.strings.shareClip.fallbackCompressionFailed;
  }
  return translations.strings.shareClip.fallbackCompressionStillTooLarge(
    limit: formatShareVideoSizeLabel(maxBytes),
  );
}
