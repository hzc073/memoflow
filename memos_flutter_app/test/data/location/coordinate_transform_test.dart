import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/location/coordinate_transform.dart';
import 'package:memos_flutter_app/data/location/models/canonical_coordinate.dart';

void main() {
  const beijing = CanonicalCoordinate(
    latitude: 39.908823,
    longitude: 116.39747,
  );
  const sanFrancisco = CanonicalCoordinate(
    latitude: 37.7749,
    longitude: -122.4194,
  );

  test('round-trips between WGS84 and GCJ-02 for coordinates in China', () {
    final gcj02 = wgs84ToGcj02(beijing);
    final restored = gcj02ToWgs84(gcj02);

    expect(gcj02, isNot(equals(beijing)));
    expect(restored.latitude, closeTo(beijing.latitude, 0.00002));
    expect(restored.longitude, closeTo(beijing.longitude, 0.00002));
  });

  test('round-trips between WGS84 and BD-09 for coordinates in China', () {
    final bd09 = wgs84ToBd09(beijing);
    final restored = bd09ToWgs84(bd09);

    expect(bd09, isNot(equals(beijing)));
    expect(restored.latitude, closeTo(beijing.latitude, 0.00002));
    expect(restored.longitude, closeTo(beijing.longitude, 0.00002));
  });

  test('does not shift overseas coordinates for GCJ-02 and BD-09 helpers', () {
    expect(wgs84ToGcj02(sanFrancisco), sanFrancisco);
    expect(gcj02ToWgs84(sanFrancisco), sanFrancisco);
    expect(gcj02ToBd09(sanFrancisco), sanFrancisco);
    expect(bd09ToGcj02(sanFrancisco), sanFrancisco);
    expect(wgs84ToBd09(sanFrancisco), sanFrancisco);
    expect(bd09ToWgs84(sanFrancisco), sanFrancisco);
  });
}
