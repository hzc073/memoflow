import 'image_preview_edit_result.dart';
import 'image_preview_item.dart';

class ImagePreviewOpenRequest {
  const ImagePreviewOpenRequest({
    required this.items,
    required this.initialIndex,
    this.onReplace,
    this.enableDownload = true,
    this.albumName = 'MemoFlow',
  });

  final List<ImagePreviewItem> items;
  final int initialIndex;
  final Future<void> Function(ImagePreviewEditResult result)? onReplace;
  final bool enableDownload;
  final String albumName;
}
