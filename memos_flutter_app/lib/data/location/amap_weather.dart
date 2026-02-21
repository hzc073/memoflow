import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/log_sanitizer.dart';
import '../logs/log_manager.dart';

class AmapWeatherLive {
  const AmapWeatherLive({
    required this.province,
    required this.city,
    required this.adcode,
    required this.weather,
    required this.temperature,
    required this.windDirection,
    required this.windPower,
    required this.humidity,
    required this.reportTime,
  });

  final String province;
  final String city;
  final String adcode;
  final String weather;
  final String temperature;
  final String windDirection;
  final String windPower;
  final String humidity;
  final String reportTime;

  factory AmapWeatherLive.fromJson(Map<String, dynamic> json) {
    String readString(String key) {
      final raw = json[key];
      if (raw is String) return raw.trim();
      return '';
    }

    return AmapWeatherLive(
      province: readString('province'),
      city: readString('city'),
      adcode: readString('adcode'),
      weather: readString('weather'),
      temperature: readString('temperature'),
      windDirection: readString('winddirection'),
      windPower: readString('windpower'),
      humidity: readString('humidity'),
      reportTime: readString('reporttime'),
    );
  }
}

class AmapWeatherClient {
  AmapWeatherClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<AmapWeatherLive?> fetchLiveWeather({
    required String apiKey,
    String? securityKey,
    required String city,
  }) async {
    final key = apiKey.trim();
    final cityCode = city.trim();
    if (key.isEmpty || cityCode.isEmpty) {
      _logWarn(
        'AMap weather skipped due missing required parameters',
        context: {
          'hasApiKey': key.isNotEmpty,
          'city': cityCode.isEmpty ? '<empty>' : cityCode,
        },
      );
      return null;
    }

    final params = <MapEntry<String, String>>[
      MapEntry('key', key),
      MapEntry('city', cityCode),
      const MapEntry('extensions', 'base'),
      const MapEntry('output', 'JSON'),
    ];
    params.sort((a, b) => a.key.compareTo(b.key));

    final encodedQuery = params
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    var url = 'https://restapi.amap.com/v3/weather/weatherInfo?$encodedQuery';

    final secret = (securityKey ?? '').trim();
    if (secret.isNotEmpty) {
      final rawQuery = params.map((e) => '${e.key}=${e.value}').join('&');
      final sig = md5.convert(utf8.encode('$rawQuery$secret')).toString();
      url = '$url&sig=$sig';
    }
    final safeUrl = _sanitizeUrlForLog(url);
    _logInfo(
      'AMap weather request start',
      context: {
        'url': safeUrl,
        'city': cityCode,
        'hasSecurityKey': secret.isNotEmpty,
      },
    );

    try {
      final response = await _dio.get(url);
      final json = _normalizeJson(response.data);
      if (json == null) {
        _logWarn(
          'AMap weather response is not valid JSON',
          context: {
            'url': safeUrl,
            'statusCode': response.statusCode,
            'body': _stringifyBody(response.data),
          },
        );
        return null;
      }
      final status = json['status']?.toString() ?? '';
      if (status != '1') {
        _logWarn(
          'AMap weather returned non-success status',
          context: {
            'url': safeUrl,
            'status': status,
            'info': json['info']?.toString(),
            'infocode': json['infocode']?.toString(),
          },
        );
        return null;
      }
      final lives = json['lives'];
      if (lives is! List || lives.isEmpty) {
        _logWarn(
          'AMap weather response contains empty lives',
          context: {'url': safeUrl, 'statusCode': response.statusCode},
        );
        return null;
      }
      final first = lives.first;
      if (first is! Map) {
        _logWarn(
          'AMap weather response has invalid lives item',
          context: {'url': safeUrl, 'statusCode': response.statusCode},
        );
        return null;
      }
      final parsed = AmapWeatherLive.fromJson(first.cast<String, dynamic>());
      _logInfo(
        'AMap weather request success',
        context: {
          'url': safeUrl,
          'province': parsed.province,
          'city': parsed.city,
          'adcode': parsed.adcode,
          'weather': parsed.weather,
          'temperature': parsed.temperature,
        },
      );
      return parsed;
    } on DioException catch (e) {
      _logError(
        'AMap weather request failed',
        error: e,
        stackTrace: e.stackTrace,
        context: {
          'url': safeUrl,
          'statusCode': e.response?.statusCode,
          'statusMessage': e.response?.statusMessage,
          'message': e.message,
          'response': _stringifyBody(e.response?.data),
          'query': _stringifyBody(_sanitizeQueryForLog(params)),
        },
      );
      return null;
    } catch (e, stackTrace) {
      _logError(
        'AMap weather request crashed',
        error: e,
        stackTrace: stackTrace,
        context: {'url': safeUrl},
      );
      return null;
    }
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

  void _logInfo(String message, {Map<String, Object?>? context}) {
    LogManager.instance.info(message, context: context);
  }

  void _logWarn(String message, {Map<String, Object?>? context}) {
    LogManager.instance.warn(message, context: context);
  }

  void _logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    LogManager.instance.error(
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
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

  bool _isSensitiveQueryKey(String key) {
    final lower = key.trim().toLowerCase();
    return lower == 'key' || lower == 'sig';
  }

  String? _stringifyBody(Object? data) {
    if (data == null) return null;
    final sanitized = LogSanitizer.sanitizeJson(data);
    final text = LogSanitizer.stringify(sanitized, maxLength: 2000).trim();
    return text.isEmpty ? null : text;
  }
}
