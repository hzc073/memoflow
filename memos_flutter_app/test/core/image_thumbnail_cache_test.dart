import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/image_thumbnail_cache.dart';

void main() {
  group('resolveThumbnailCacheExtent', () {
    test('returns null for invalid input', () {
      expect(resolveThumbnailCacheExtent(0, 3), isNull);
      expect(resolveThumbnailCacheExtent(120, 0), isNull);
      expect(resolveThumbnailCacheExtent(double.nan, 3), isNull);
    });

    test('scales by device pixel ratio and overscan', () {
      expect(resolveThumbnailCacheExtent(100, 2), 300);
      expect(resolveThumbnailCacheExtent(100, 2, overscan: 1), 200);
    });

    test('caps decode extent at max decode px', () {
      expect(resolveThumbnailCacheExtent(500, 3), 1024);
      expect(resolveThumbnailCacheExtent(500, 3, maxDecodePx: 768), 768);
    });
  });
}
