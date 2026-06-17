import 'package:flutter/material.dart';

import '../media_preview/media_preview_launcher.dart';
import 'image_preview_open_request.dart';

class ImagePreviewLauncher {
  const ImagePreviewLauncher._();

  static Future<void> open(
    BuildContext context,
    ImagePreviewOpenRequest request,
  ) async {
    await MediaPreviewLauncher.openImagePreview(context, request);
  }
}
