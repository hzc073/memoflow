int? resolveThumbnailCacheExtent(
  double logicalExtent,
  double devicePixelRatio, {
  double overscan = 1.5,
  int maxDecodePx = 1024,
}) {
  if (!logicalExtent.isFinite || logicalExtent <= 0) return null;
  if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) return null;
  if (maxDecodePx <= 0) return null;
  final normalizedOverscan = overscan.isFinite && overscan > 0 ? overscan : 1.0;
  final pixels = (logicalExtent * devicePixelRatio * normalizedOverscan)
      .round();
  if (pixels <= 0) return null;
  return pixels > maxDecodePx ? maxDecodePx : pixels;
}
