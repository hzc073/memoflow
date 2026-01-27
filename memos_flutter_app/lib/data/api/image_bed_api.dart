import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/image_bed_url.dart';

class ImageBedRequestException implements Exception {
  ImageBedRequestException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ImageBedApi {
  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _receiveTimeout = Duration(seconds: 30);

  static Future<String> createLskyToken({
    required Uri baseUrl,
    required String email,
    required String password,
  }) async {
    final dio = _buildDio(imageBedLegacyApiBase(baseUrl));
    try {
      final response = await dio.post(
        'tokens',
        data: {
          'email': email,
          'password': password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final body = _expectJsonMap(response.data);
      if (!_isTruthy(body['status'])) {
        throw ImageBedRequestException(_extractMessage(body) ?? 'Token request failed');
      }
      final data = body['data'];
      if (data is Map) {
        final token = _readString(data['token']);
        if (token.isNotEmpty) return token;
      }
      throw ImageBedRequestException('Token missing in response');
    } on DioException catch (e) {
      throw _wrapDioException(e, fallback: 'Token request failed');
    }
  }

  static Future<String> uploadLskyLegacy({
    required Uri baseUrl,
    required List<int> bytes,
    required String filename,
    String? token,
    String? strategyId,
  }) async {
    final dio = _buildDio(imageBedLegacyApiBase(baseUrl));
    final data = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      if (strategyId != null && strategyId.trim().isNotEmpty) 'strategy_id': strategyId.trim(),
    });
    try {
      final response = await dio.post(
        'upload',
        data: data,
        options: Options(
          headers: token == null || token.trim().isEmpty ? null : {'Authorization': 'Bearer ${token.trim()}'},
        ),
      );
      final body = _expectJsonMap(response.data);
      if (!_isTruthy(body['status'])) {
        throw ImageBedRequestException(_extractMessage(body) ?? 'Upload failed', statusCode: response.statusCode);
      }
      final url = _extractLegacyImageUrl(body);
      if (url.isEmpty) {
        throw ImageBedRequestException('Image URL missing in response', statusCode: response.statusCode);
      }
      return url;
    } on DioException catch (e) {
      throw _wrapDioException(e, fallback: 'Upload failed');
    }
  }

  static Future<String> uploadLskyModern({
    required Uri baseUrl,
    required List<int> bytes,
    required String filename,
    required String storageId,
  }) async {
    final dio = _buildDio(imageBedModernApiBase(baseUrl));
    final data = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      'storage_id': storageId.trim(),
    });
    try {
      final response = await dio.post('upload', data: data);
      final body = _expectJsonMap(response.data);
      if (!_isTruthy(body['status']) && _extractModernImageUrl(body).isEmpty) {
        throw ImageBedRequestException(_extractMessage(body) ?? 'Upload failed', statusCode: response.statusCode);
      }
      final url = _extractModernImageUrl(body);
      if (url.isEmpty) {
        throw ImageBedRequestException('Image URL missing in response', statusCode: response.statusCode);
      }
      return url;
    } on DioException catch (e) {
      throw _wrapDioException(e, fallback: 'Upload failed');
    }
  }

  static Dio _buildDio(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: _normalizeBaseUrl(baseUrl),
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        headers: const {'Accept': 'application/json'},
      ),
    );
  }

  static String _normalizeBaseUrl(String raw) {
    var trimmed = raw.trim();
    if (!trimmed.endsWith('/')) {
      trimmed = '$trimmed/';
    }
    return trimmed;
  }

  static Map<String, dynamic> _expectJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    if (value is Map) return value.cast<String, dynamic>();
    throw const FormatException('Expected JSON object');
  }

  static String _readString(dynamic value) {
    if (value is String) return value.trim();
    if (value == null) return '';
    return value.toString().trim();
  }

  static String? _extractMessage(Map<String, dynamic> body) {
    final msg = body['message'] ?? body['error'] ?? body['detail'];
    if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    return null;
  }

  static bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == 'success' || normalized == 'ok' || normalized == '1';
    }
    return false;
  }

  static String _extractLegacyImageUrl(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map) {
      final links = data['links'];
      if (links is Map) {
        final url = _readString(links['url']);
        if (url.isNotEmpty) return url;
        final markdown = _readString(links['markdown']);
        final extracted = _extractUrlFromMarkdown(markdown);
        if (extracted.isNotEmpty) return extracted;
      }
      final fallback = _readString(data['url'] ?? data['public_url']);
      if (fallback.isNotEmpty) return fallback;
    }
    return '';
  }

  static String _extractModernImageUrl(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map) {
      final url = _readString(data['public_url'] ?? data['url']);
      if (url.isNotEmpty) return url;
      final links = data['links'];
      if (links is Map) {
        final linkUrl = _readString(links['url']);
        if (linkUrl.isNotEmpty) return linkUrl;
        final markdown = _readString(links['markdown']);
        final extracted = _extractUrlFromMarkdown(markdown);
        if (extracted.isNotEmpty) return extracted;
      }
    }
    return '';
  }

  static String _extractUrlFromMarkdown(String markdown) {
    if (markdown.isEmpty) return '';
    final match = RegExp(r'!\[[^\]]*\]\(([^)\s]+)\)').firstMatch(markdown);
    return match?.group(1)?.trim() ?? '';
  }

  static ImageBedRequestException _wrapDioException(DioException e, {required String fallback}) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String message = '';
    if (data is Map) {
      message = _extractMessage(data.cast<String, dynamic>()) ?? '';
    } else if (data is String) {
      message = data.trim();
    }
    if (message.isEmpty) {
      message = fallback;
    }
    return ImageBedRequestException(message, statusCode: status);
  }
}
