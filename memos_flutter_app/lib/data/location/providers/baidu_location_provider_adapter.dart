import 'package:dio/dio.dart';

import '../../models/location_settings.dart';
import '../coordinate_transform.dart';
import '../location_adapter_utils.dart';
import '../location_provider_adapter.dart';
import '../models/canonical_coordinate.dart';
import '../models/location_candidate.dart';
import '../models/provider_place_ref.dart';

class BaiduLocationProviderAdapter implements LocationProviderAdapter {
  BaiduLocationProviderAdapter({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  CanonicalCoordinate fromProviderCoordinate(ProviderCoordinate coordinate) {
    final providerCoordinate = CanonicalCoordinate(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
    );
    return switch (coordinate.system) {
      ProviderCoordinateSystem.bd09 => bd09ToWgs84(providerCoordinate),
      ProviderCoordinateSystem.gcj02 => gcj02ToWgs84(providerCoordinate),
      ProviderCoordinateSystem.wgs84 => providerCoordinate,
    };
  }

  @override
  ProviderCoordinate toProviderCoordinate(CanonicalCoordinate coordinate) {
    final converted = wgs84ToBd09(coordinate);
    return ProviderCoordinate(
      latitude: converted.latitude,
      longitude: converted.longitude,
      system: ProviderCoordinateSystem.bd09,
    );
  }

  @override
  Future<String?> reverseGeocode({
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
  }) async {
    final json = await _reverse(
      coordinate: coordinate,
      settings: settings,
      includePois: false,
    );
    if (json == null) return null;
    final result = json['result'];
    if (result is! Map) return null;
    final formatted = readString(result['formatted_address']);
    final component = result['addressComponent'];
    if (component is! Map) {
      return formatted.isEmpty ? null : formatted;
    }
    final province = readString(component['province']);
    final city = readString(component['city']);
    final district = readString(component['district']);
    final street = readString(component['street']);
    final number = readString(component['street_number']);
    final streetPart = [street, number].where((part) => part.isNotEmpty).join();
    final summary = formatLocationPrecisionSummary(
      precision: settings.precision,
      province: province,
      city: city,
      district: district,
      street: streetPart,
      fallback: formatted,
    );
    return summary.isEmpty ? null : summary;
  }

  @override
  Future<List<LocationCandidate>> searchNearby({
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
    int radiusMeters = 1000,
    int limit = 10,
  }) async {
    final json = await _reverse(
      coordinate: coordinate,
      settings: settings,
      includePois: true,
      radiusMeters: radiusMeters,
    );
    if (json == null) return const <LocationCandidate>[];
    final result = json['result'];
    if (result is! Map) return const <LocationCandidate>[];
    final pois = result['pois'];
    if (pois is! List) return const <LocationCandidate>[];
    final candidates = <LocationCandidate>[];
    for (final item in pois) {
      if (item is! Map) continue;
      final name = readString(item['name']);
      if (name.isEmpty) continue;
      final locationMap = item['point'] ?? item['location'];
      final canonicalCoordinate = _readProviderCoordinate(locationMap);
      if (canonicalCoordinate == null) continue;
      candidates.add(
        LocationCandidate(
          title: name,
          subtitle: readString(item['addr']),
          coordinate: canonicalCoordinate,
          distanceMeters: readDouble(item['distance']),
          placeRef: ProviderPlaceRef(
            providerId: readString(item['uid']),
            providerName: LocationServiceProvider.baidu.name,
            raw: Map<String, dynamic>.from(item.cast<String, dynamic>()),
          ),
          source: LocationCandidateSource.nearby,
        ),
      );
    }
    return sortAndLimitCandidates(candidates, coordinate, limit: limit);
  }

  @override
  Future<List<LocationCandidate>> searchByKeyword({
    required String query,
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
    int radiusMeters = 1000,
    int limit = 10,
  }) async {
    final trimmedQuery = query.trim();
    final key = settings.baiduWebKey.trim();
    if (trimmedQuery.isEmpty || key.isEmpty) return const <LocationCandidate>[];
    final response = await _dio.get(
      'https://api.map.baidu.com/place/v2/search',
      queryParameters: <String, dynamic>{
        'query': trimmedQuery,
        'location': '${coordinate.latitude.toStringAsFixed(6)},${coordinate.longitude.toStringAsFixed(6)}',
        'radius': radiusMeters,
        'output': 'json',
        'scope': 2,
        'page_size': limit,
        'page_num': 0,
        'coord_type': 'wgs84ll',
        'ak': key,
      },
    );
    final data = response.data;
    if (data is! Map) return const <LocationCandidate>[];
    final status = data['status'];
    final isOk = status is num ? status.toInt() == 0 : status?.toString() == '0';
    if (!isOk) return const <LocationCandidate>[];
    final results = data['results'];
    if (results is! List) return const <LocationCandidate>[];
    final candidates = <LocationCandidate>[];
    for (final item in results) {
      if (item is! Map) continue;
      final name = readString(item['name']);
      if (name.isEmpty) continue;
      final coordinateValue = _readProviderCoordinate(item['location']);
      if (coordinateValue == null) continue;
      final detailInfo = item['detail_info'];
      candidates.add(
        LocationCandidate(
          title: name,
          subtitle: readString(item['address']),
          coordinate: coordinateValue,
          distanceMeters: detailInfo is Map ? readDouble(detailInfo['distance']) : null,
          placeRef: ProviderPlaceRef(
            providerId: readString(item['uid']),
            providerName: LocationServiceProvider.baidu.name,
            raw: Map<String, dynamic>.from(item.cast<String, dynamic>()),
          ),
          source: LocationCandidateSource.keyword,
        ),
      );
    }
    return sortAndLimitCandidates(candidates, coordinate, limit: limit);
  }

  Future<Map<String, dynamic>?> _reverse({
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
    required bool includePois,
    int radiusMeters = 1000,
  }) async {
    final key = settings.baiduWebKey.trim();
    if (key.isEmpty) return null;
    final response = await _dio.get(
      'https://api.map.baidu.com/reverse_geocoding/v3/',
      queryParameters: <String, dynamic>{
        'ak': key,
        'output': 'json',
        'coordtype': 'wgs84ll',
        'extensions_poi': includePois ? 1 : 0,
        'radius': radiusMeters,
        'location': '${coordinate.latitude.toStringAsFixed(6)},${coordinate.longitude.toStringAsFixed(6)}',
      },
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return null;
  }

  CanonicalCoordinate? _readProviderCoordinate(dynamic value) {
    if (value is Map) {
      final lat = readDouble(value['lat'] ?? value['y']);
      final lng = readDouble(value['lng'] ?? value['x']);
      if (lat == null || lng == null) return null;
      return fromProviderCoordinate(
        ProviderCoordinate(
          latitude: lat,
          longitude: lng,
          system: ProviderCoordinateSystem.bd09,
        ),
      );
    }
    return null;
  }
}
