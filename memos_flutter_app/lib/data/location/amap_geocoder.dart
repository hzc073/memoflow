import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/log_sanitizer.dart';
import '../logs/log_manager.dart';
import '../logs/network_log_buffer.dart';
import '../logs/network_log_store.dart';

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
      final requestId = '${start.microsecondsSinceEpoch}-${hashCode}';
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
      return _parseDisplayName(data);
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

  String? _parseDisplayName(Map<String, dynamic> json) {
    final status = json['status']?.toString();
    if (status != '1') return null;
    final regeocode = json['regeocode'];
    if (regeocode is! Map) return null;
    final address = regeocode['addressComponent'];
    if (address is! Map) return null;
    final province = _readString(address['province']);
    final city = _readCity(address['city']);
    final district = _readString(address['district']);

    final region = _mergeRegion(province, city);
    if (region.isEmpty && district.isEmpty) return null;
    if (district.isEmpty) return region.isEmpty ? null : region;
    if (region.isEmpty) return district;
    return '$region · $district';
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
