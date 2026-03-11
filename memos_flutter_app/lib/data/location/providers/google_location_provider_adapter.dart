import 'package:dio/dio.dart';

import '../../models/location_settings.dart';
import '../location_adapter_utils.dart';
import '../location_provider_adapter.dart';
import '../models/canonical_coordinate.dart';
import '../models/location_candidate.dart';
import '../models/provider_place_ref.dart';

class GoogleLocationProviderAdapter implements LocationProviderAdapter {
  GoogleLocationProviderAdapter({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  CanonicalCoordinate fromProviderCoordinate(ProviderCoordinate coordinate) {
    return CanonicalCoordinate(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
    );
  }

  @override
  ProviderCoordinate toProviderCoordinate(CanonicalCoordinate coordinate) {
    return ProviderCoordinate(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      system: ProviderCoordinateSystem.wgs84,
    );
  }

  @override
  Future<String?> reverseGeocode({
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
  }) async {
    final key = settings.googleApiKey.trim();
    if (key.isEmpty) return null;
    final response = await _dio.get(
      'https://maps.googleapis.com/maps/api/geocode/json',
      queryParameters: <String, dynamic>{
        'latlng': '${coordinate.latitude.toStringAsFixed(6)},${coordinate.longitude.toStringAsFixed(6)}',
        'key': key,
      },
    );
    final data = response.data;
    if (data is! Map) return null;
    final status = readString(data['status']);
    if (status != 'OK') return null;
    final results = data['results'];
    if (results is! List || results.isEmpty) return null;
    final first = results.first;
    if (first is! Map) return null;
    final formattedAddress = readString(first['formatted_address']);
    final addressComponents = first['address_components'];
    if (addressComponents is! List) {
      return formattedAddress.isEmpty ? null : formattedAddress;
    }

    String findFirst(Set<String> types) {
      for (final component in addressComponents) {
        if (component is! Map) continue;
        final rawTypes = component['types'];
        if (rawTypes is! List) continue;
        final normalizedTypes = rawTypes.map((type) => type.toString()).toSet();
        if (normalizedTypes.intersection(types).isEmpty) continue;
        final value = readString(component['long_name']);
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final province = findFirst({'administrative_area_level_1'});
    final city = findFirst({
      'administrative_area_level_2',
      'locality',
      'postal_town',
    });
    final district = findFirst({
      'sublocality',
      'sublocality_level_1',
      'administrative_area_level_3',
      'neighborhood',
    });
    final route = findFirst({'route'});
    final streetNumber = findFirst({'street_number'});
    final street = [route, streetNumber].where((part) => part.isNotEmpty).join(' ');
    final summary = formatLocationPrecisionSummary(
      precision: settings.precision,
      province: province,
      city: city,
      district: district,
      street: street,
      fallback: formattedAddress,
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
    final key = settings.googleApiKey.trim();
    if (key.isEmpty) return const <LocationCandidate>[];
    final response = await _dio.get(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
      queryParameters: <String, dynamic>{
        'location': '${coordinate.latitude.toStringAsFixed(6)},${coordinate.longitude.toStringAsFixed(6)}',
        'radius': radiusMeters,
        'key': key,
      },
    );
    return _parsePlaceResults(
      response.data,
      coordinate: coordinate,
      source: LocationCandidateSource.nearby,
      limit: limit,
    );
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
    final key = settings.googleApiKey.trim();
    if (trimmedQuery.isEmpty || key.isEmpty) return const <LocationCandidate>[];
    final response = await _dio.get(
      'https://maps.googleapis.com/maps/api/place/textsearch/json',
      queryParameters: <String, dynamic>{
        'query': trimmedQuery,
        'location': '${coordinate.latitude.toStringAsFixed(6)},${coordinate.longitude.toStringAsFixed(6)}',
        'radius': radiusMeters,
        'key': key,
      },
    );
    return _parsePlaceResults(
      response.data,
      coordinate: coordinate,
      source: LocationCandidateSource.keyword,
      limit: limit,
    );
  }

  List<LocationCandidate> _parsePlaceResults(
    dynamic raw, {
    required CanonicalCoordinate coordinate,
    required LocationCandidateSource source,
    required int limit,
  }) {
    if (raw is! Map) return const <LocationCandidate>[];
    final status = readString(raw['status']);
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      return const <LocationCandidate>[];
    }
    final results = raw['results'];
    if (results is! List) return const <LocationCandidate>[];
    final candidates = <LocationCandidate>[];
    for (final item in results) {
      if (item is! Map) continue;
      final name = readString(item['name']);
      final geometry = item['geometry'];
      final location = geometry is Map ? geometry['location'] : null;
      if (name.isEmpty || location is! Map) continue;
      final lat = readDouble(location['lat']);
      final lng = readDouble(location['lng']);
      if (lat == null || lng == null) continue;
      final canonical = CanonicalCoordinate(latitude: lat, longitude: lng);
      candidates.add(
        LocationCandidate(
          title: name,
          subtitle: readString(item['formatted_address'] ?? item['vicinity']),
          coordinate: canonical,
          placeRef: ProviderPlaceRef(
            providerId: readString(item['place_id']),
            providerName: LocationServiceProvider.google.name,
            raw: Map<String, dynamic>.from(item.cast<String, dynamic>()),
          ),
          source: source,
        ),
      );
    }
    return sortAndLimitCandidates(candidates, coordinate, limit: limit);
  }
}

