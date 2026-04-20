import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/attachments/attachment_preprocessor.dart';
import '../settings/image_compression_settings_provider.dart';

final attachmentPreprocessorProvider = Provider<AttachmentPreprocessor>((ref) {
  final repo = ref.watch(imageCompressionSettingsRepositoryProvider);
  return DefaultAttachmentPreprocessor(loadSettings: repo.read);
});
