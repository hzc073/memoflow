import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../image_preview_edit_result.dart';
import '../image_preview_open_request.dart';
import 'image_preview_gallery_body.dart';

class ImagePreviewGalleryScreen extends StatelessWidget {
  const ImagePreviewGalleryScreen({
    super.key,
    required this.request,
    this.isDesktopOverride,
    this.editResultOverride,
    this.editImageOverride,
    this.editActionOverride,
    this.confirmReplaceOverride,
  });

  final ImagePreviewOpenRequest request;
  final bool? isDesktopOverride;
  final Future<ImagePreviewEditResult?> Function()? editResultOverride;
  final Future<Uint8List?> Function(Uint8List imageBytes)? editImageOverride;
  final Future<ImagePreviewGalleryEditAction?> Function()? editActionOverride;
  final Future<bool> Function()? confirmReplaceOverride;

  @override
  Widget build(BuildContext context) {
    return ImagePreviewGalleryBody(
      request: request,
      isDesktopOverride: isDesktopOverride,
      editResultOverride: editResultOverride,
      editImageOverride: editImageOverride,
      editActionOverride: editActionOverride,
      confirmReplaceOverride: confirmReplaceOverride,
    );
  }
}
