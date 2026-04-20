import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/location_launcher.dart';
import 'package:memos_flutter_app/data/location/coordinate_transform.dart';
import 'package:memos_flutter_app/data/location/models/canonical_coordinate.dart';

void main() {
  group('AMap launch URIs', () {
    test('candidate order prefers web handoff before app scheme', () {
      final uris = debugBuildAmapCandidates(
        latitude: 39.908823,
        longitude: 116.39747,
        label: 'Tiananmen',
      );

      expect(uris, hasLength(2));
      expect(uris.first.scheme, equals('https'));
      expect(uris.last.scheme, equals('androidamap'));
    });

    test('app uri converts WGS84 coordinates to GCJ-02 in China', () {
      const coordinate = CanonicalCoordinate(
        latitude: 39.908823,
        longitude: 116.39747,
      );
      final converted = wgs84ToGcj02(coordinate);

      final uri = debugBuildAmapAppUri(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        label: 'Tiananmen',
      );

      expect(uri.scheme, equals('androidamap'));
      expect(
        double.parse(uri.queryParameters['lat']!),
        closeTo(converted.latitude, 0.000001),
      );
      expect(
        double.parse(uri.queryParameters['lon']!),
        closeTo(converted.longitude, 0.000001),
      );
      expect(uri.queryParameters['dev'], equals('0'));
      expect(uri.queryParameters['poiname'], equals('Tiananmen'));
    });

    test('web uri keeps WGS84 coordinates and enables native fallback', () {
      final uri = debugBuildAmapWebUri(
        latitude: 39.908823,
        longitude: 116.39747,
        label: 'Tiananmen',
      );

      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('uri.amap.com'));
      expect(uri.queryParameters['position'], equals('116.397470,39.908823'));
      expect(uri.queryParameters['coordinate'], equals('wgs84'));
      expect(uri.queryParameters['callnative'], equals('1'));
      expect(uri.queryParameters['name'], equals('Tiananmen'));
    });

    test('app uri keeps coordinates unchanged outside China', () {
      final uri = debugBuildAmapAppUri(
        latitude: 37.7749,
        longitude: -122.4194,
        label: 'San Francisco',
      );

      expect(
        double.parse(uri.queryParameters['lat']!),
        closeTo(37.7749, 0.000001),
      );
      expect(
        double.parse(uri.queryParameters['lon']!),
        closeTo(-122.4194, 0.000001),
      );
    });
  });

  group('other map candidate order', () {
    test('Baidu prefers web handoff before app scheme', () {
      final uris = debugBuildBaiduCandidates(
        lat: '39.908823',
        lng: '116.397470',
        label: 'Tiananmen',
      );

      expect(uris, hasLength(2));
      expect(uris.first.scheme, equals('https'));
      expect(uris.last.scheme, equals('baidumap'));
    });

    test('Google prefers web handoff before app scheme', () {
      final uris = debugBuildGoogleCandidates(
        lat: '39.908823',
        lng: '116.397470',
        label: 'Tiananmen',
      );

      expect(uris, hasLength(2));
      expect(uris.first.scheme, equals('https'));
      expect(uris.last.scheme, equals('geo'));
    });
  });
}
