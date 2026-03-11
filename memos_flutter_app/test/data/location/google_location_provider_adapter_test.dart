import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/location/models/canonical_coordinate.dart';
import 'package:memos_flutter_app/data/location/providers/google_location_provider_adapter.dart';
import 'package:memos_flutter_app/data/models/location_settings.dart';

void main() {
  const settings = LocationSettings(
    enabled: true,
    provider: LocationServiceProvider.google,
    amapWebKey: '',
    amapSecurityKey: '',
    baiduWebKey: '',
    googleApiKey: 'google-key',
    precision: LocationPrecision.city,
  );

  test('formats reverse geocode response using precision summary', () async {
    final adapter = GoogleLocationProviderAdapter(
      dio: _buildFakeDio((options) {
        expect(options.path, contains('/geocode/json'));
        return <String, dynamic>{
          'status': 'OK',
          'results': [
            {
              'formatted_address': 'No. 1 Huangyu Avenue, Ouhai, Wenzhou, Zhejiang',
              'address_components': [
                {
                  'long_name': '\u6d59\u6c5f\u7701',
                  'types': ['administrative_area_level_1'],
                },
                {
                  'long_name': '\u6e29\u5dde\u5e02',
                  'types': ['locality'],
                },
                {
                  'long_name': '\u74ef\u6d77\u533a',
                  'types': ['sublocality_level_1'],
                },
              ],
            },
          ],
        };
      }),
    );

    final result = await adapter.reverseGeocode(
      coordinate: const CanonicalCoordinate(
        latitude: 27.9815,
        longitude: 120.6978,
      ),
      settings: settings.copyWith(precision: LocationPrecision.district),
    );

    expect(result, '\u6e29\u5dde\u5e02\u2022\u74ef\u6d77\u533a');
  });

  test('parses reverse geocode responses', () async {
    final adapter = GoogleLocationProviderAdapter(
      dio: _buildFakeDio((options) {
        expect(options.path, contains('/geocode/json'));
        return <String, dynamic>{
          'status': 'OK',
          'results': [
            {'formatted_address': '1600 Amphitheatre Parkway'},
          ],
        };
      }),
    );

    final result = await adapter.reverseGeocode(
      coordinate: const CanonicalCoordinate(
        latitude: 37.422,
        longitude: -122.084,
      ),
      settings: settings,
    );

    expect(result, '1600 Amphitheatre Parkway');
  });

  test('parses and sorts nearby search results', () async {
    final adapter = GoogleLocationProviderAdapter(
      dio: _buildFakeDio((_) {
        return <String, dynamic>{
          'status': 'OK',
          'results': [
            {
              'name': 'Far Place',
              'vicinity': 'Far Road',
              'place_id': 'far',
              'geometry': {
                'location': {'lat': 37.432, 'lng': -122.094},
              },
            },
            {
              'name': 'Near Place',
              'vicinity': 'Near Road',
              'place_id': 'near',
              'geometry': {
                'location': {'lat': 37.4221, 'lng': -122.0841},
              },
            },
          ],
        };
      }),
    );

    final results = await adapter.searchNearby(
      coordinate: const CanonicalCoordinate(
        latitude: 37.422,
        longitude: -122.084,
      ),
      settings: settings,
    );

    expect(results, hasLength(2));
    expect(results.first.title, 'Near Place');
    expect(results.first.subtitle, 'Near Road');
    expect(results.first.placeRef?.providerId, 'near');
  });

  test('returns empty results when API key is missing', () async {
    final adapter = GoogleLocationProviderAdapter(dio: Dio());
    final missingKeySettings = settings.copyWith(googleApiKey: '');

    final reverse = await adapter.reverseGeocode(
      coordinate: const CanonicalCoordinate(
        latitude: 37.422,
        longitude: -122.084,
      ),
      settings: missingKeySettings,
    );
    final nearby = await adapter.searchNearby(
      coordinate: const CanonicalCoordinate(
        latitude: 37.422,
        longitude: -122.084,
      ),
      settings: missingKeySettings,
    );
    final keyword = await adapter.searchByKeyword(
      query: 'coffee',
      coordinate: const CanonicalCoordinate(
        latitude: 37.422,
        longitude: -122.084,
      ),
      settings: missingKeySettings,
    );

    expect(reverse, isNull);
    expect(nearby, isEmpty);
    expect(keyword, isEmpty);
  });
}

Dio _buildFakeDio(
  Map<String, dynamic> Function(RequestOptions options) handler,
) {
  final dio = Dio();
  dio.httpClientAdapter = _FakeHttpClientAdapter(handler);
  return dio;
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this._handler);

  final Map<String, dynamic> Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final payload = jsonEncode(_handler(options));
    return ResponseBody.fromString(
      payload,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
