import 'dart:convert';

import 'package:dio/dio.dart';

import 'update_config.dart';

const Duration kUpdateConfigTimeout = Duration(seconds: 3);
const List<String> kUpdateConfigUrls = [
  'https://juanzeng.hzc073.com/memoflow/update/latest.json',
  'https://hzc073.github.io/memoflow_config/update/latest.json',
  'https://raw.githubusercontent.com/hzc073/memoflow_config/gh-pages/update/latest.json',
  'https://raw.githubusercontent.com/hzc073/memoflow_config/main/memoflow_update.json',
];

class UpdateConfigService {
  UpdateConfigService({Dio? dio, List<String>? configUrls})
    : _dio = dio ?? Dio(),
      _configUrls = configUrls ?? kUpdateConfigUrls;

  final Dio _dio;
  final List<String> _configUrls;

  Future<UpdateAnnouncementConfig?> fetchLatest({
    Duration timeout = kUpdateConfigTimeout,
  }) async {
    for (final url in _configUrls) {
      final trimmed = url.trim();
      if (trimmed.isEmpty) continue;
      final config = await _fetchFromUrl(trimmed, timeout: timeout);
      if (config != null) return config;
    }
    return null;
  }

  Future<UpdateAnnouncementConfig?> _fetchFromUrl(
    String url, {
    required Duration timeout,
  }) async {
    try {
      _dio.options
        ..connectTimeout = timeout
        ..sendTimeout = timeout
        ..receiveTimeout = timeout;
      final response = await _dio.get<dynamic>(
        url,
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      final data = response.data;
      final decoded = data is String ? jsonDecode(data) : data;
      if (decoded is Map) {
        final config = UpdateAnnouncementConfig.fromJson(
          decoded.cast<String, dynamic>(),
        );
        return config;
      }
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
    return null;
  }
}
