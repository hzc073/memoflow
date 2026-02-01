import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/log_sanitizer.dart';
import '../logs/log_manager.dart';
import '../logs/network_log_buffer.dart';
import '../logs/network_log_store.dart';
import '../models/location_settings.dart';

class AmapGeocodeResult {
  const AmapGeocodeResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });

  final double latitude;
  final double longitude;
  final String displayName;
}

class AmapGeocoder {
  AmapGeocoder({
    Dio? dio,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    LogManager? logManager,
  })  : _dio = dio ?? Dio(),
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
    String? securityKey,
    LocationPrecision precision = LocationPrecision.city,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) return null;

    final location = _formatLocation(longitude, latitude);
    final params = <MapEntry<String, String>>[
      MapEntry('key', key),
      MapEntry('location', location),
      const MapEntry('output', 'JSON'),
      const MapEntry('radius', '1000'),
      const MapEntry('extensions', 'base'),
    ];
    params.sort((a, b) => a.key.compareTo(b.key));

    final encodedQuery = params.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    var url = 'https://restapi.amap.com/v3/geocode/regeo?$encodedQuery';

    final secret = (securityKey ?? '').trim();
    if (secret.isNotEmpty) {
      final rawQuery = params.map((e) => '${e.key}=${e.value}').join('&');
      final sig = md5.convert(utf8.encode('$rawQuery$secret')).toString();
      url = '$url&sig=$sig';
    }

    try {
      final start = DateTime.now().toUtc();
      final requestId = '$start.microsecondsSinceEpoch-$hashCode';
      final safeUrl = _sanitizeUrlForLog(url);
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

      final response = await _dio.get(url);
      final end = DateTime.now().toUtc();
      final durationMs = end.difference(start).inMilliseconds;
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
          timestamp: start,
          method: 'GET',
          path: Uri.parse(url).path,
          query: _stringifyBody(_sanitizeQueryForLog(params)),
          requestBody: null,
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
          durationMs: durationMs,
          responseBody: _stringifyBody(response.data),
          errorMessage: null,
        ),
      );
      final data = _normalizeJson(response.data);
      if (data == null) return null;
      return _parseDisplayName(data, precision: precision);
    } on DioException catch (e) {
      final now = DateTime.now().toUtc();
      final safeUrl = _sanitizeUrlForLog(url);
      final status = e.response?.statusCode;
      if (_logStore?.enabled ?? false) {
        _logStore!.add(
          NetworkLogEntry(
            timestamp: now,
            type: 'error',
            method: 'GET',
            url: safeUrl,
            status: status,
            body: _stringifyBody(e.response?.data),
            error: LogSanitizer.sanitizeText(e.message ?? 'request failed'),
          ),
        );
      }
      _logManager?.error(
        'HTTP GET $safeUrl failed',
        error: e,
        stackTrace: e.stackTrace,
        context: {
          'status': status,
          'response': _stringifyBody(e.response?.data),
        },
      );
      _logBuffer?.add(
        NetworkRequestLog(
          timestamp: now,
          method: 'GET',
          path: Uri.tryParse(url)?.path ?? '/v3/geocode/regeo',
          query: _stringifyBody(_sanitizeQueryForLog(params)),
          requestBody: null,
          statusCode: status,
          statusMessage: e.response?.statusMessage,
          durationMs: null,
          responseBody: _stringifyBody(e.response?.data),
          errorMessage: LogSanitizer.sanitizeText(e.message ?? 'request failed'),
        ),
      );
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<AmapGeocodeResult?> geocodeAddress({
    required String address,
    String? city,
    required String apiKey,
    String? securityKey,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) return null;
    final rawAddress = address.trim();
    if (rawAddress.isEmpty) return null;

    final params = <MapEntry<String, String>>[
      MapEntry('key', key),
      MapEntry('address', rawAddress),
      const MapEntry('output', 'JSON'),
    ];
    final cityValue = (city ?? '').trim();
    if (cityValue.isNotEmpty) {
      params.add(MapEntry('city', cityValue));
    }
    params.sort((a, b) => a.key.compareTo(b.key));

    final encodedQuery = params.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    var url = 'https://restapi.amap.com/v3/geocode/geo?$encodedQuery';

    final secret = (securityKey ?? '').trim();
    if (secret.isNotEmpty) {
      final rawQuery = params.map((e) => '${e.key}=${e.value}').join('&');
      final sig = md5.convert(utf8.encode('$rawQuery$secret')).toString();
      url = '$url&sig=$sig';
    }

    try {
      final start = DateTime.now().toUtc();
      final requestId = '$start.microsecondsSinceEpoch-$hashCode';
      final safeUrl = _sanitizeUrlForLog(url);
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

      final response = await _dio.get(url);
      final end = DateTime.now().toUtc();
      final durationMs = end.difference(start).inMilliseconds;
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
          timestamp: start,
          method: 'GET',
          path: Uri.parse(url).path,
          query: _stringifyBody(_sanitizeQueryForLog(params)),
          requestBody: null,
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
          durationMs: durationMs,
          responseBody: _stringifyBody(response.data),
          errorMessage: null,
        ),
      );
      final data = _normalizeJson(response.data);
      if (data == null) return null;
      return _parseGeocodeResult(data);
    } on DioException catch (e) {
      final now = DateTime.now().toUtc();
      final safeUrl = _sanitizeUrlForLog(url);
      final status = e.response?.statusCode;
      if (_logStore?.enabled ?? false) {
        _logStore!.add(
          NetworkLogEntry(
            timestamp: now,
            type: 'error',
            method: 'GET',
            url: safeUrl,
            status: status,
            body: _stringifyBody(e.response?.data),
            error: LogSanitizer.sanitizeText(e.message ?? 'request failed'),
          ),
        );
      }
      _logManager?.error(
        'HTTP GET $safeUrl failed',
        error: e,
        stackTrace: e.stackTrace,
        context: {
          'status': status,
          'response': _stringifyBody(e.response?.data),
        },
      );
      _logBuffer?.add(
        NetworkRequestLog(
          timestamp: now,
          method: 'GET',
          path: Uri.tryParse(url)?.path ?? '/v3/geocode/geo',
          query: _stringifyBody(_sanitizeQueryForLog(params)),
          requestBody: null,
          statusCode: status,
          statusMessage: e.response?.statusMessage,
          durationMs: null,
          responseBody: _stringifyBody(e.response?.data),
          errorMessage: LogSanitizer.sanitizeText(e.message ?? 'request failed'),
        ),
      );
      return null;
    } catch (_) {
      return null;
    }
  }

  String _formatLocation(double longitude, double latitude) {
    final lng = longitude.toStringAsFixed(6);
    final lat = latitude.toStringAsFixed(6);
    return '$lng,$lat';
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

  String? _parseDisplayName(Map<String, dynamic> json, {required LocationPrecision precision}) {
    final status = json['status']?.toString();
    if (status != '1') return null;
    final regeocode = json['regeocode'];
    if (regeocode is! Map) return null;
    final formatted = _readString(regeocode['formatted_address']);
    final address = regeocode['addressComponent'];
    if (address is! Map) {
      return formatted.isNotEmpty ? formatted : null;
    }
    final province = _readString(address['province']);
    final city = _readCity(address['city']);
    final district = _readString(address['district']);
    var street = '';
    var number = '';
    final streetNumber = address['streetNumber'];
    if (streetNumber is Map) {
      street = _readString(streetNumber['street']);
      number = _readString(streetNumber['number']);
    }

    final region = _mergeRegion(province, city);
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
          if (street.isNotEmpty) street,
          if (number.isNotEmpty) number,
        ];
        if (parts.isNotEmpty) return parts.join();
        if (formatted.isNotEmpty) return formatted;
        break;
    }
    if (formatted.isNotEmpty) return formatted;
    return null;
  }

  AmapGeocodeResult? _parseGeocodeResult(Map<String, dynamic> json) {
    final status = json['status']?.toString();
    if (status != '1') return null;
    final geocodes = json['geocodes'];
    if (geocodes is! List || geocodes.isEmpty) return null;
    final first = geocodes.first;
    if (first is! Map) return null;
    final formattedAddress = _readString(first['formatted_address']);
    final province = _readString(first['province']);
    final city = _readCity(first['city']);
    final district = _readString(first['district']);
    final street = _readString(first['street']);
    final number = _readString(first['number']);
    final location = _readString(first['location']);
    final coords = _parseLocation(location);
    if (coords == null) return null;
    final displayName = formattedAddress.isNotEmpty
        ? formattedAddress
        : _buildGeocodeDisplayName(
            province: province,
            city: city,
            district: district,
            street: street,
            number: number,
          );
    return AmapGeocodeResult(
      latitude: coords.$2,
      longitude: coords.$1,
      displayName: displayName.isEmpty ? location : displayName,
    );
  }

  (double, double)? _parseLocation(String raw) {
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lng = double.tryParse(parts[0].trim());
    final lat = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return (lng, lat);
  }

  String _buildGeocodeDisplayName({
    required String province,
    required String city,
    required String district,
    required String street,
    required String number,
  }) {
    final region = _mergeRegion(province, city);
    final streetPart = [street, number].where((part) => part.isNotEmpty).join();
    final parts = <String>[
      if (region.isNotEmpty) region,
      if (district.isNotEmpty) district,
      if (streetPart.isNotEmpty) streetPart,
    ];
    return parts.join();
  }

  String _readString(dynamic value) {
    if (value is String) return value.trim();
    return value?.toString().trim() ?? '';
  }

  String _readCity(dynamic value) {
    if (value is String) return value.trim();
    if (value is List) {
      if (value.isEmpty) return '';
      final first = value.first;
      if (first is String) return first.trim();
    }
    return '';
  }

  String _mergeRegion(String province, String city) {
    final parts = <String>[];
    if (province.isNotEmpty) {
      parts.add(province);
    }
    if (city.isNotEmpty && city != province) {
      parts.add(city);
    }
    return parts.join();
  }

  String _sanitizeUrlForLog(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return LogSanitizer.maskUrl(url);
    final qp = Map<String, String>.from(uri.queryParameters);
    qp.updateAll((key, value) => _isSensitiveQueryKey(key) ? LogSanitizer.maskToken(value) : value);
    final sanitized = uri.replace(queryParameters: qp);
    return LogSanitizer.maskUrl(sanitized.toString());
  }

  bool _isSensitiveQueryKey(String key) {
    final lower = key.trim().toLowerCase();
    return lower == 'key' || lower == 'sig';
  }

  Map<String, String> _sanitizeQueryForLog(List<MapEntry<String, String>> params) {
    final out = <String, String>{};
    for (final entry in params) {
      final key = entry.key;
      final value = entry.value;
      out[key] = _isSensitiveQueryKey(key) ? LogSanitizer.maskToken(value) : value;
    }
    return out;
  }

  String? _stringifyBody(Object? data) {
    if (data == null) return null;
    final sanitized = LogSanitizer.sanitizeJson(data);
    final text = LogSanitizer.stringify(sanitized, maxLength: 4000).trim();
    return text.isEmpty ? null : text;
  }
}

