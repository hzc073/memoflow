class ImagePreviewEditResult {
  const ImagePreviewEditResult({
    required this.sourceId,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  final String sourceId;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
}
