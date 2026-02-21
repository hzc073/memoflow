import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/log_sanitizer.dart';
import '../logs/log_manager.dart';
import '../logs/network_log_buffer.dart';
import '../logs/network_log_store.dart';
import '../models/location_settings.dart';
import 'amap_geocoder.dart';

class LocationGeocoder {
  LocationGeocoder({
    Dio? dio,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    LogManager? logManager,
  }) : _amap = AmapGeocoder(
         dio: dio,
         logStore: logStore,
         logBuffer: logBuffer,
         logManager: logManager,
       ),
       _baidu = _BaiduGeocoder(
         dio: dio,
         logStore: logStore,
         logBuffer: logBuffer,
         logManager: logManager,
       ),
       _google = _GoogleGeocoder(
         dio: dio,
         logStore: logStore,
         logBuffer: logBuffer,
         logManager: logManager,
       );

  final AmapGeocoder _amap;
  final _BaiduGeocoder _baidu;
  final _GoogleGeocoder _google;

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
    required LocationSettings settings,
  }) async {
    switch (settings.provider) {
      case LocationServiceProvider.amap:
        final apiKey = settings.amapWebKey.trim();
        if (apiKey.isEmpty) return null;
        return _amap.reverseGeocode(
          latitude: latitude,
          longitude: longitude,
          apiKey: apiKey,
          securityKey: settings.amapSecurityKey,
          precision: settings.precision,
        );
      case LocationServiceProvider.baidu:
        final apiKey = settings.baiduWebKey.trim();
        if (apiKey.isEmpty) return null;
        return _baidu.reverseGeocode(
          latitude: latitude,
          longitude: longitude,
          apiKey: apiKey,
          precision: settings.precision,
        );
      case LocationServiceProvider.google:
        final apiKey = settings.googleApiKey.trim();
        if (apiKey.isEmpty) return null;
        return _google.reverseGeocode(
          latitude: latitude,
          longitude: longitude,
          apiKey: apiKey,
          precision: settings.precision,
        );
    }
  }
}

class _BaiduGeocoder {
  _BaiduGeocoder({
    Dio? dio,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    LogManager? logManager,
  }) : _dio = dio ?? Dio(),
       _logStore = logStore,
       _logBuffer = logBuffer,
       _logManager = logManager;

  final Dio _dio;
  final NetworkLogStore? _logStore;
  final NetworkLogBuffer? _logBuffer;
  final LogManager? _logManager;

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
    required String apiKey,
    LocationPrecision precision = LocationPrecision.city,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) return null;

    final location =
        '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
    final params = <MapEntry<String, String>>[
      MapEntry('ak', key),
      const MapEntry('output', 'json'),
      const MapEntry('coordtype', 'wgs84ll'),
      MapEntry('location', location),
    ];
    params.sort((a, b) => a.key.compareTo(b.key));

    final encodedQuery = params
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url = 'https://api.map.baidu.com/reverse_geocoding/v3/?$encodedQuery';
    final safeUrl = _sanitizeUrlForLog(url);

    final start = DateTime.now().toUtc();
    final requestId = '$start.microsecondsSinceEpoch-$hashCode';
    _addRequestLog(start: start, requestId: requestId, safeUrl: safeUrl);

    try {
      final response = await _dio.get(url);
      final end = DateTime.now().toUtc();
      final durationMs = end.difference(start).inMilliseconds;
      _addResponseLog(
        end: end,
        requestId: requestId,
        safeUrl: safeUrl,
        response: response,
        durationMs: durationMs,
      );
      final data = _normalizeJson(response.data);
      if (data == null) return null;
      return _parseDisplayName(data, precision: precision);
    } on DioException catch (e) {
      _addErrorLog(safeUrl: safeUrl, error: e, params: params);
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _parseDisplayName(
    Map<String, dynamic> json, {
    required LocationPrecision precision,
  }) {
    final status = json['status'];
    final isOk = status is num
        ? status.toInt() == 0
        : status?.toString() == '0';
    if (!isOk) return null;
    final result = json['result'];
    if (result is! Map) return null;
    final formatted = _readString(result['formatted_address']);
    final component = result['addressComponent'];
    if (component is! Map) {
      return formatted.isNotEmpty ? formatted : null;
    }

    final province = _readString(component['province']);
    final city = _readString(component['city']);
    final district = _readString(component['district']);
    final street = _readString(component['street']);
    final number = _readString(component['street_number']);
    final region = _mergeRegion(province, city);
    final streetPart = [street, number].where((part) => part.isNotEmpty).join();

    switch (precision) {
      case LocationPrecision.province:
        if (province.isNotEmpty) return province;
        if (region.isNotEmpty) return region;
        if (district.isNotEmpty) return district;
        break;
      case LocationPrecision.city:
        if (region.isNotEmpty) return region;
        if (province.isNotEmpty) return province;
        if (district.isNotEmpty) return district;
        break;
      case LocationPrecision.district:
        final parts = <String>[
          if (region.isNotEmpty) region,
          if (district.isNotEmpty) district,
        ];
        if (parts.isNotEmpty) return parts.join();
        break;
      case LocationPrecision.street:
        final parts = <String>[
          if (region.isNotEmpty) region,
          if (district.isNotEmpty) district,
          if (streetPart.isNotEmpty) streetPart,
        ];
        if (parts.isNotEmpty) return parts.join();
        break;
    }
    if (formatted.isNotEmpty) return formatted;
    return null;
  }

  String _readString(dynamic value) {
    if (value is String) return value.trim();
    return value?.toString().trim() ?? '';
  }

  String _mergeRegion(String province, String city) {
    if (province.isEmpty) return city;
    if (city.isEmpty || city == province) return province;
    return '$province$city';
  }

  Map<String, dynamic>? _normalizeJson(dynamic data) {
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (_) {}
    }
    return null;
  }

  String _sanitizeUrlForLog(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return LogSanitizer.maskUrl(url);
    final qp = Map<String, String>.from(uri.queryParameters);
    qp.updateAll(
      (key, value) =>
          _isSensitiveQueryKey(key) ? LogSanitizer.maskToken(value) : value,
    );
    final sanitized = uri.replace(queryParameters: qp);
    return LogSanitizer.maskUrl(sanitized.toString());
  }

  bool _isSensitiveQueryKey(String key) {
    final lower = key.trim().toLowerCase();
    return lower == 'ak' || lower == 'sn';
  }

  Map<String, String> _sanitizeQueryForLog(
    List<MapEntry<String, String>> params,
  ) {
    final out = <String, String>{};
    for (final entry in params) {
      final key = entry.key;
      final value = entry.value;
      out[key] = _isSensitiveQueryKey(key)
          ? LogSanitizer.maskToken(value)
          : value;
    }
    return out;
  }

  String? _stringifyBody(Object? data) {
    if (data == null) return null;
    final sanitized = LogSanitizer.sanitizeJson(data);
    final text = LogSanitizer.stringify(sanitized, maxLength: 4000).trim();
    return text.isEmpty ? null : text;
  }

  void _addRequestLog({
    required DateTime start,
    required String requestId,
    required String safeUrl,
  }) {
    if (_logStore?.enabled ?? false) {
      _logStore!.add(
        NetworkLogEntry(
          timestamp: start,
          type: 'request',
          method: 'GET',
          url: safeUrl,
          requestId: requestId,
        ),
      );
    }
  }

  void _addResponseLog({
    required DateTime end,
    required String requestId,
    required String safeUrl,
    required Response<dynamic> response,
    required int durationMs,
  }) {
    if (_logStore?.enabled ?? false) {
      _logStore!.add(
        NetworkLogEntry(
          timestamp: end,
          type: 'response',
          method: 'GET',
          url: safeUrl,
          status: response.statusCode,
          durationMs: durationMs,
          body: _stringifyBody(response.data),
          requestId: requestId,
        ),
      );
    }
    _logManager?.info(
      'HTTP GET $safeUrl',
      context: {
        'status': response.statusCode,
        'durationMs': durationMs,
        if (requestId.isNotEmpty) 'requestId': requestId,
      },
    );
    _logBuffer?.add(
      NetworkRequestLog(
        timestamp: end,
        method: 'GET',
        path: Uri.parse(safeUrl).path,
        query: null,
        requestBody: null,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        durationMs: durationMs,
        responseBody: _stringifyBody(response.data),
        errorMessage: null,
      ),
    );
  }

  void _addErrorLog({
    required String safeUrl,
    required DioException error,
    required List<MapEntry<String, String>> params,
  }) {
    final now = DateTime.now().toUtc();
    final status = error.response?.statusCode;
    if (_logStore?.enabled ?? false) {
      _logStore!.add(
        NetworkLogEntry(
          timestamp: now,
          type: 'error',
          method: 'GET',
          url: safeUrl,
          status: status,
          body: _stringifyBody(error.response?.data),
          error: LogSanitizer.sanitizeText(error.message ?? 'request failed'),
        ),
      );
    }
    _logManager?.error(
      'HTTP GET $safeUrl failed',
      error: error,
      stackTrace: error.stackTrace,
      context: {
        'status': status,
        'response': _stringifyBody(error.response?.data),
      },
    );
    _logBuffer?.add(
      NetworkRequestLog(
        timestamp: now,
        method: 'GET',
        path: Uri.tryParse(safeUrl)?.path ?? '/reverse_geocoding/v3/',
        query: _stringifyBody(_sanitizeQueryForLog(params)),
        requestBody: null,
        statusCode: status,
        statusMessage: error.response?.statusMessage,
        durationMs: null,
        responseBody: _stringifyBody(error.response?.data),
        errorMessage: LogSanitizer.sanitizeText(
          error.message ?? 'request failed',
        ),
      ),
    );
  }
}

class _GoogleGeocoder {
  _GoogleGeocoder({
    Dio? dio,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    LogManager? logManager,
  }) : _dio = dio ?? Dio(),
       _logStore = logStore,
       _logBuffer = logBuffer,
       _logManager = logManager;

  final Dio _dio;
  final NetworkLogStore? _logStore;
  final NetworkLogBuffer? _logBuffer;
  final LogManager? _logManager;

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
    required String apiKey,
    LocationPrecision precision = LocationPrecision.city,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) return null;

    final latLng =
        '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
    final params = <MapEntry<String, String>>[
      MapEntry('key', key),
      MapEntry('latlng', latLng),
      const MapEntry('language', 'zh-CN'),
    ];
    params.sort((a, b) => a.key.compareTo(b.key));

    final encodedQuery = params
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?$encodedQuery';
    final safeUrl = _sanitizeUrlForLog(url);

    final start = DateTime.now().toUtc();
    final requestId = '$start.microsecondsSinceEpoch-$hashCode';
    _addRequestLog(start: start, requestId: requestId, safeUrl: safeUrl);

    try {
      final response = await _dio.get(url);
      final end = DateTime.now().toUtc();
      final durationMs = end.difference(start).inMilliseconds;
      _addResponseLog(
        end: end,
        requestId: requestId,
        safeUrl: safeUrl,
        response: response,
        durationMs: durationMs,
      );
      final data = _normalizeJson(response.data);
      if (data == null) return null;
      return _parseDisplayName(data, precision: precision);
    } on DioException catch (e) {
      _addErrorLog(safeUrl: safeUrl, error: e, params: params);
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _parseDisplayName(
    Map<String, dynamic> json, {
    required LocationPrecision precision,
  }) {
    final status = _readString(json['status']).toUpperCase();
    if (status != 'OK') return null;
    final results = json['results'];
    if (results is! List || results.isEmpty) return null;
    final first = results.first;
    if (first is! Map) return null;
    final formatted = _readString(first['formatted_address']);
    final componentsRaw = first['address_components'];
    if (componentsRaw is! List) {
      return formatted.isNotEmpty ? formatted : null;
    }

    final components = <_GoogleAddressComponent>[];
    for (final item in componentsRaw) {
      if (item is! Map) continue;
      final longName = _readString(item['long_name']);
      if (longName.isEmpty) continue;
      final typeRaw = item['types'];
      final types = <String>{};
      if (typeRaw is List) {
        for (final type in typeRaw) {
          final value = _readString(type).toLowerCase();
          if (value.isNotEmpty) {
            types.add(value);
          }
        }
      }
      components.add(_GoogleAddressComponent(longName: longName, types: types));
    }

    String findFirst(Set<String> targetTypes) {
      for (final component in components) {
        for (final type in targetTypes) {
          if (component.types.contains(type)) return component.longName;
        }
      }
      return '';
    }

    final province = findFirst({'administrative_area_level_1'});
    final city = findFirst({
      'locality',
      'administrative_area_level_2',
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
    final street = _joinParts([route, streetNumber], ' ');
    final region = _joinParts([province, city], ', ');

    switch (precision) {
      case LocationPrecision.province:
        if (province.isNotEmpty) return province;
        if (city.isNotEmpty) return city;
        if (district.isNotEmpty) return district;
        break;
      case LocationPrecision.city:
        if (region.isNotEmpty) return region;
        if (province.isNotEmpty) return province;
        if (city.isNotEmpty) return city;
        if (district.isNotEmpty) return district;
        break;
      case LocationPrecision.district:
        final value = _joinParts([region, district], ', ');
        if (value.isNotEmpty) return value;
        break;
      case LocationPrecision.street:
        final value = _joinParts([region, district, street], ', ');
        if (value.isNotEmpty) return value;
        break;
    }
    if (formatted.isNotEmpty) return formatted;
    return null;
  }

  String _readString(dynamic value) {
    if (value is String) return value.trim();
    return value?.toString().trim() ?? '';
  }

  String _joinParts(List<String> parts, String separator) {
    return parts.where((part) => part.trim().isNotEmpty).join(separator);
  }

  Map<String, dynamic>? _normalizeJson(dynamic data) {
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (_) {}
    }
    return null;
  }

  String _sanitizeUrlForLog(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return LogSanitizer.maskUrl(url);
    final qp = Map<String, String>.from(uri.queryParameters);
    qp.updateAll(
      (key, value) =>
          _isSensitiveQueryKey(key) ? LogSanitizer.maskToken(value) : value,
    );
    final sanitized = uri.replace(queryParameters: qp);
    return LogSanitizer.maskUrl(sanitized.toString());
  }

  bool _isSensitiveQueryKey(String key) {
    final lower = key.trim().toLowerCase();
    return lower == 'key';
  }

  Map<String, String> _sanitizeQueryForLog(
    List<MapEntry<String, String>> params,
  ) {
    final out = <String, String>{};
    for (final entry in params) {
      final key = entry.key;
      final value = entry.value;
      out[key] = _isSensitiveQueryKey(key)
          ? LogSanitizer.maskToken(value)
          : value;
    }
    return out;
  }

  String? _stringifyBody(Object? data) {
    if (data == null) return null;
    final sanitized = LogSanitizer.sanitizeJson(data);
    final text = LogSanitizer.stringify(sanitized, maxLength: 4000).trim();
    return text.isEmpty ? null : text;
  }

  void _addRequestLog({
    required DateTime start,
    required String requestId,
    required String safeUrl,
  }) {
    if (_logStore?.enabled ?? false) {
      _logStore!.add(
        NetworkLogEntry(
          timestamp: start,
          type: 'request',
          method: 'GET',
          url: safeUrl,
          requestId: requestId,
        ),
      );
    }
  }

  void _addResponseLog({
    required DateTime end,
    required String requestId,
    required String safeUrl,
    required Response<dynamic> response,
    required int durationMs,
  }) {
    if (_logStore?.enabled ?? false) {
      _logStore!.add(
        NetworkLogEntry(
          timestamp: end,
          type: 'response',
          method: 'GET',
          url: safeUrl,
          status: response.statusCode,
          durationMs: durationMs,
          body: _stringifyBody(response.data),
          requestId: requestId,
        ),
      );
    }
    _logManager?.info(
      'HTTP GET $safeUrl',
      context: {
        'status': response.statusCode,
        'durationMs': durationMs,
        if (requestId.isNotEmpty) 'requestId': requestId,
      },
    );
    _logBuffer?.add(
      NetworkRequestLog(
        timestamp: end,
        method: 'GET',
        path: Uri.parse(safeUrl).path,
        query: null,
        requestBody: null,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        durationMs: durationMs,
        responseBody: _stringifyBody(response.data),
        errorMessage: null,
      ),
    );
  }

  void _addErrorLog({
    required String safeUrl,
    required DioException error,
    required List<MapEntry<String, String>> params,
  }) {
    final now = DateTime.now().toUtc();
    final status = error.response?.statusCode;
    if (_logStore?.enabled ?? false) {
      _logStore!.add(
        NetworkLogEntry(
          timestamp: now,
          type: 'error',
          method: 'GET',
          url: safeUrl,
          status: status,
          body: _stringifyBody(error.response?.data),
          error: LogSanitizer.sanitizeText(error.message ?? 'request failed'),
        ),
      );
    }
    _logManager?.error(
      'HTTP GET $safeUrl failed',
      error: error,
      stackTrace: error.stackTrace,
      context: {
        'status': status,
        'response': _stringifyBody(error.response?.data),
      },
    );
    _logBuffer?.add(
      NetworkRequestLog(
        timestamp: now,
        method: 'GET',
        path: Uri.tryParse(safeUrl)?.path ?? '/maps/api/geocode/json',
        query: _stringifyBody(_sanitizeQueryForLog(params)),
        requestBody: null,
        statusCode: status,
        statusMessage: error.response?.statusMessage,
        durationMs: null,
        responseBody: _stringifyBody(error.response?.data),
        errorMessage: LogSanitizer.sanitizeText(
          error.message ?? 'request failed',
        ),
      ),
    );
  }
}

class _GoogleAddressComponent {
  const _GoogleAddressComponent({required this.longName, required this.types});

  final String longName;
  final Set<String> types;
}
