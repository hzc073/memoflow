import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../../models/location_settings.dart';
import '../amap_geocoder.dart';
import '../coordinate_transform.dart';
import '../location_adapter_utils.dart';
import '../location_provider_adapter.dart';
import '../models/canonical_coordinate.dart';
import '../models/location_candidate.dart';
import '../models/provider_place_ref.dart';

class AmapLocationProviderAdapter implements LocationProviderAdapter {
  AmapLocationProviderAdapter({Dio? dio})
    : _dio = dio ?? Dio(),
      _geocoder = AmapGeocoder(dio: dio ?? Dio());

  final Dio _dio;
  final AmapGeocoder _geocoder;

  @override
  CanonicalCoordinate fromProviderCoordinate(ProviderCoordinate coordinate) {
    final providerCoordinate = CanonicalCoordinate(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
    );
    return switch (coordinate.system) {
      ProviderCoordinateSystem.gcj02 => gcj02ToWgs84(providerCoordinate),
      ProviderCoordinateSystem.bd09 => bd09ToWgs84(providerCoordinate),
      ProviderCoordinateSystem.wgs84 => providerCoordinate,
    };
  }

  @override
  ProviderCoordinate toProviderCoordinate(CanonicalCoordinate coordinate) {
    final converted = wgs84ToGcj02(coordinate);
    return ProviderCoordinate(
      latitude: converted.latitude,
      longitude: converted.longitude,
      system: ProviderCoordinateSystem.gcj02,
    );
  }

  @override
  Future<String?> reverseGeocode({
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
  }) async {
    final key = settings.amapWebKey.trim();
    if (key.isEmpty) return null;
    final providerCoordinate = toProviderCoordinate(coordinate);
    final params = <MapEntry<String, String>>[
      MapEntry('key', key),
      MapEntry(
        'location',
        '${providerCoordinate.longitude.toStringAsFixed(6)},${providerCoordinate.latitude.toStringAsFixed(6)}',
      ),
      const MapEntry('output', 'JSON'),
      const MapEntry('radius', '1000'),
      const MapEntry('extensions', 'base'),
    ];
    final json = await _getSignedJson(
      baseUrl: 'https://restapi.amap.com/v3/geocode/regeo',
      params: params,
      securityKey: settings.amapSecurityKey,
    );
    if (json == null) return null;
    final regeocode = json['regeocode'];
    if (regeocode is! Map) return null;
    final formattedAddress = readString(regeocode['formatted_address']);
    final addressComponent = regeocode['addressComponent'];
    if (addressComponent is! Map) {
      return formattedAddress.isEmpty ? null : formattedAddress;
    }
    final province = readString(addressComponent['province']);
    final city = _readAmapCity(addressComponent['city']);
    final district = readString(addressComponent['district']);
    final township = readString(addressComponent['township']);
    var street = '';
    var number = '';
    final streetNumber = addressComponent['streetNumber'];
    if (streetNumber is Map) {
      street = readString(streetNumber['street']);
      number = readString(streetNumber['number']);
    }
    final streetPart = [street, number].where((part) => part.isNotEmpty).join();
    final summary = formatLocationPrecisionSummary(
      precision: settings.precision,
      province: province,
      city: city,
      district: district,
      street: streetPart.isNotEmpty ? streetPart : township,
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
    final key = settings.amapWebKey.trim();
    if (key.isEmpty) return const <LocationCandidate>[];
    final providerCoordinate = toProviderCoordinate(coordinate);
    final params = <MapEntry<String, String>>[
      MapEntry('key', key),
      MapEntry(
        'location',
        '${providerCoordinate.longitude.toStringAsFixed(6)},${providerCoordinate.latitude.toStringAsFixed(6)}',
      ),
      const MapEntry('output', 'JSON'),
      MapEntry('radius', radiusMeters.toString()),
      const MapEntry('extensions', 'all'),
    ];
    final json = await _getSignedJson(
      baseUrl: 'https://restapi.amap.com/v3/geocode/regeo',
      params: params,
      securityKey: settings.amapSecurityKey,
    );
    if (json == null) return const <LocationCandidate>[];
    final regeocode = json['regeocode'];
    if (regeocode is! Map) return const <LocationCandidate>[];
    final pois = regeocode['pois'];
    if (pois is! List) return const <LocationCandidate>[];
    final candidates = <LocationCandidate>[];
    for (final item in pois) {
      if (item is! Map) continue;
      final name = readString(item['name']);
      final location = readString(item['location']);
      if (name.isEmpty || location.isEmpty) continue;
      final coords = location.split(',');
      if (coords.length != 2) continue;
      final lng = double.tryParse(coords[0].trim());
      final lat = double.tryParse(coords[1].trim());
      if (lng == null || lat == null) continue;
      final canonicalCoordinate = fromProviderCoordinate(
        ProviderCoordinate(
          latitude: lat,
          longitude: lng,
          system: ProviderCoordinateSystem.gcj02,
        ),
      );
      candidates.add(
        LocationCandidate(
          title: name,
          subtitle: readString(item['address']),
          coordinate: canonicalCoordinate,
          distanceMeters: readDouble(item['distance']),
          placeRef: ProviderPlaceRef(
            providerId: readString(item['id']),
            providerName: LocationServiceProvider.amap.name,
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
    final key = settings.amapWebKey.trim();
    if (trimmedQuery.isEmpty || key.isEmpty) return const <LocationCandidate>[];
    final providerCoordinate = toProviderCoordinate(coordinate);
    final params = <MapEntry<String, String>>[
      MapEntry('key', key),
      MapEntry('keywords', trimmedQuery),
      MapEntry('offset', limit.toString()),
      const MapEntry('page', '1'),
      const MapEntry('extensions', 'all'),
      MapEntry(
        'location',
        '${providerCoordinate.longitude.toStringAsFixed(6)},${providerCoordinate.latitude.toStringAsFixed(6)}',
      ),
    ];
    final json = await _getSignedJson(
      baseUrl: 'https://restapi.amap.com/v3/place/text',
      params: params,
      securityKey: settings.amapSecurityKey,
    );
    final candidates = <LocationCandidate>[];
    final pois = json?['pois'];
    if (pois is List) {
      for (final item in pois) {
        if (item is! Map) continue;
        final name = readString(item['name']);
        final location = readString(item['location']);
        if (name.isEmpty || location.isEmpty) continue;
        final coords = location.split(',');
        if (coords.length != 2) continue;
        final lng = double.tryParse(coords[0].trim());
        final lat = double.tryParse(coords[1].trim());
        if (lng == null || lat == null) continue;
        final canonicalCoordinate = fromProviderCoordinate(
          ProviderCoordinate(
            latitude: lat,
            longitude: lng,
            system: ProviderCoordinateSystem.gcj02,
          ),
        );
        candidates.add(
          LocationCandidate(
            title: name,
            subtitle: readString(item['address']),
            coordinate: canonicalCoordinate,
            placeRef: ProviderPlaceRef(
              providerId: readString(item['id']),
              providerName: LocationServiceProvider.amap.name,
              raw: Map<String, dynamic>.from(item.cast<String, dynamic>()),
            ),
            source: LocationCandidateSource.keyword,
          ),
        );
      }
    }
    if (candidates.isEmpty) {
      final fallback = await _geocoder.geocodeAddress(
        address: trimmedQuery,
        apiKey: key,
        securityKey: settings.amapSecurityKey,
      );
      if (fallback != null) {
        candidates.add(
          LocationCandidate(
            title: trimmedQuery,
            subtitle: fallback.displayName,
            coordinate: fromProviderCoordinate(
              ProviderCoordinate(
                latitude: fallback.latitude,
                longitude: fallback.longitude,
                system: ProviderCoordinateSystem.gcj02,
              ),
            ),
            source: LocationCandidateSource.keyword,
          ),
        );
      }
    }
    return sortAndLimitCandidates(candidates, coordinate, limit: limit);
  }


  String _readAmapCity(dynamic value) {
    if (value is String) return value.trim();
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is String) return first.trim();
    }
    return '';
  }

  Future<Map<String, dynamic>?> _getSignedJson({
    required String baseUrl,
    required List<MapEntry<String, String>> params,
    String? securityKey,
  }) async {
    final sortedParams = List<MapEntry<String, String>>.from(params)
      ..sort((a, b) => a.key.compareTo(b.key));
    final encodedQuery = sortedParams
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    var url = '$baseUrl?$encodedQuery';
    final secret = (securityKey ?? '').trim();
    if (secret.isNotEmpty) {
      final rawQuery = sortedParams.map((entry) => '${entry.key}=${entry.value}').join('&');
      final sig = md5.convert(utf8.encode('$rawQuery$secret')).toString();
      url = '$url&sig=$sig';
    }
    final response = await _dio.get(url);
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return null;
  }
}
