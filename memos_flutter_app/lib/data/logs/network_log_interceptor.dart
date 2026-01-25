import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/log_sanitizer.dart';
import 'breadcrumb_store.dart';
import 'log_manager.dart';
import 'network_log_buffer.dart';
import 'network_log_store.dart';

class NetworkLogInterceptor extends Interceptor {
  NetworkLogInterceptor(
    this._store, {
    this.maxBodyLength = 4000,
    NetworkLogBuffer? buffer,
    BreadcrumbStore? breadcrumbStore,
    LogManager? logManager,
  })  : _buffer = buffer,
        _breadcrumbs = breadcrumbStore,
        _logManager = logManager;

  final NetworkLogStore? _store;
  final NetworkLogBuffer? _buffer;
  final BreadcrumbStore? _breadcrumbs;
  final LogManager? _logManager;
  final int maxBodyLength;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final now = DateTime.now().toUtc();
    final requestId = '${now.microsecondsSinceEpoch}-${options.hashCode}';
    options.extra[_logStartKey] = now;
    options.extra[_logIdKey] = requestId;
    options.extra[_logMetaKey] = _RequestMeta(
      start: now,
      method: options.method.toUpperCase(),
      path: _resolvePath(options),
      query: _stringifyCompact(options.queryParameters),
      body: _stringifyBody(_normalizeRequestData(options.data)),
    );

    if (_store?.enabled ?? false) {
      final entry = NetworkLogEntry(
        timestamp: now,
        type: 'request',
        method: options.method.toUpperCase(),
        url: LogSanitizer.maskUrl(options.uri.toString()),
        headers: _sanitizeHeaders(options.headers),
        body: _stringifyBody(_normalizeRequestData(options.data)),
        requestId: requestId,
      );
      unawaited(_store!.add(entry));
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final now = DateTime.now().toUtc();
    final started = response.requestOptions.extra[_logStartKey];
    final durationMs =
        started is DateTime ? now.difference(started).inMilliseconds : null;
    final requestId = response.requestOptions.extra[_logIdKey]?.toString();
    if (_store?.enabled ?? false) {
      final entry = NetworkLogEntry(
        timestamp: now,
        type: 'response',
        method: response.requestOptions.method.toUpperCase(),
        url: LogSanitizer.maskUrl(response.requestOptions.uri.toString()),
        status: response.statusCode,
        durationMs: durationMs,
        headers: _sanitizeResponseHeaders(response.headers),
        body: _stringifyBody(response.data),
        requestId: requestId,
      );
      unawaited(_store!.add(entry));
    }
    _logManager?.info(
      'HTTP ${response.requestOptions.method.toUpperCase()} ${LogSanitizer.maskUrl(response.requestOptions.uri.toString())}',
      context: {
        'status': response.statusCode,
        'durationMs': durationMs,
        'summary': _summarizeResponse(response.data),
        if (requestId != null) 'requestId': requestId,
      },
    );
    _appendBufferEntry(
      requestOptions: response.requestOptions,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      responseBody: response.data,
      errorMessage: null,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final now = DateTime.now().toUtc();
    final started = err.requestOptions.extra[_logStartKey];
    final durationMs =
        started is DateTime ? now.difference(started).inMilliseconds : null;
    final requestId = err.requestOptions.extra[_logIdKey]?.toString();
    if (_store?.enabled ?? false) {
      final entry = NetworkLogEntry(
        timestamp: now,
        type: 'error',
        method: err.requestOptions.method.toUpperCase(),
        url: LogSanitizer.maskUrl(err.requestOptions.uri.toString()),
        status: err.response?.statusCode,
        durationMs: durationMs,
        headers: _sanitizeResponseHeaders(err.response?.headers),
        body: _stringifyBody(err.response?.data),
        error: LogSanitizer.sanitizeText(err.message ?? 'request failed'),
        requestId: requestId,
      );
      unawaited(_store!.add(entry));
    }
    _logManager?.error(
      'HTTP ${err.requestOptions.method.toUpperCase()} ${LogSanitizer.maskUrl(err.requestOptions.uri.toString())} failed',
      error: err,
      stackTrace: err.stackTrace,
      context: {
        'status': err.response?.statusCode,
        'durationMs': durationMs,
        'response': _stringifyBody(err.response?.data),
        if (requestId != null) 'requestId': requestId,
      },
    );
    final sanitizedError = LogSanitizer.sanitizeText(err.message ?? 'request failed');
    _appendBufferEntry(
      requestOptions: err.requestOptions,
      statusCode: err.response?.statusCode,
      statusMessage: err.response?.statusMessage,
      responseBody: err.response?.data,
      errorMessage: sanitizedError,
    );
    final method = err.requestOptions.method.toUpperCase();
    final path = _resolvePath(err.requestOptions);
    final statusLabel = err.response?.statusCode?.toString() ?? '?';
    final detail = sanitizedError.trim().isEmpty ? '' : ' - $sanitizedError';
    _breadcrumbs?.add('Error: $method $path (HTTP $statusLabel)$detail');
    handler.next(err);
  }

  Map<String, String> _sanitizeHeaders(Map<String, dynamic> headers) {
    final out = <String, String>{};
    headers.forEach((key, value) {
      final k = key.toString();
      final lower = k.toLowerCase();
      if (lower == 'authorization' || lower.contains('token') || lower == 'cookie') {
        out[k] = LogSanitizer.maskToken(value?.toString() ?? '');
        return;
      }
      out[k] = LogSanitizer.sanitizeText(value?.toString() ?? '');
    });
    return out;
  }

  Map<String, String> _sanitizeResponseHeaders(Headers? headers) {
    if (headers == null) return const {};
    final out = <String, String>{};
    headers.map.forEach((key, values) {
      final lower = key.toLowerCase();
      final joined = values.join('; ');
      if (lower == 'set-cookie' || lower == 'cookie' || lower.contains('token')) {
        out[key] = LogSanitizer.maskToken(joined);
        return;
      }
      out[key] = LogSanitizer.sanitizeText(joined);
    });
    return out;
  }

  Object? _normalizeRequestData(Object? data) {
    if (data is FormData) {
      final out = <String, Object?>{};
      for (final field in data.fields) {
        out[field.key] = field.value;
      }
      if (data.files.isNotEmpty) {
        out['files'] = data.files.map((entry) {
          final file = entry.value;
          return <String, Object?>{
            'field': entry.key,
            'filename': file.filename ?? '',
            'contentType': file.contentType?.toString() ?? '',
            'length': file.length,
          };
        }).toList(growable: false);
      }
      return out;
    }
    if (data is List<int>) {
      return '<bytes:${data.length}>';
    }
    return data;
  }

  String? _stringifyBody(Object? data) {
    if (data == null) return null;
    final normalized = _promotePaginationFields(data);
    final sanitized = LogSanitizer.sanitizeJson(normalized);
    final text = LogSanitizer.stringify(sanitized, maxLength: maxBodyLength);
    return text.trim().isEmpty ? null : text;
  }

  Object? _promotePaginationFields(Object? data) {
    if (data is Map) {
      final map = <String, Object?>{};
      final nextToken = data['nextPageToken'];
      final nextTokenAlt = data['next_page_token'];
      final memosRaw = data['memos'];
      final memosCount = memosRaw is List ? memosRaw.length : null;
      if (nextToken != null) map['nextPageToken'] = nextToken;
      if (nextTokenAlt != null) map['next_page_token'] = nextTokenAlt;
      if (memosCount != null) map['memosCount'] = memosCount;
      data.forEach((key, value) {
        final k = key.toString();
        if (k == 'nextPageToken' || k == 'next_page_token') return;
        if (k == 'memosCount') return;
        map[k] = value;
      });
      return map;
    }
    return data;
  }

  String _resolvePath(RequestOptions options) {
    final path = options.uri.path;
    if (path.isNotEmpty) return path;
    return options.path;
  }

  String? _stringifyCompact(Object? data) {
    final text = _stringifyBody(data);
    if (text == null) return null;
    if (text == '{}' || text == '[]') return null;
    return text;
  }

  void _appendBufferEntry({
    required RequestOptions requestOptions,
    required int? statusCode,
    required String? statusMessage,
    required Object? responseBody,
    required String? errorMessage,
  }) {
    final buffer = _buffer;
    if (buffer == null) return;

    final meta = requestOptions.extra[_logMetaKey] as _RequestMeta?;
    final now = DateTime.now().toUtc();
    final started = requestOptions.extra[_logStartKey];
    final durationMs = started is DateTime ? now.difference(started).inMilliseconds : null;
    final requestBody = meta?.body;
    final requestQuery = meta?.query;
    final responseText = _stringifyBody(responseBody);
    final queryParams = requestOptions.queryParameters;
    final pageSize = _parseInt(queryParams['pageSize'] ?? queryParams['page_size']);
    final pageToken = _parseToken(queryParams['pageToken'] ?? queryParams['page_token']);
    final pagination = _extractPagination(responseBody);

    buffer.add(
      NetworkRequestLog(
        timestamp: meta?.start ?? now,
        method: (meta?.method ?? requestOptions.method).toUpperCase(),
        path: meta?.path ?? _resolvePath(requestOptions),
        query: requestQuery,
        requestBody: requestBody,
        statusCode: statusCode,
        statusMessage: statusMessage,
        durationMs: durationMs,
        responseBody: responseText,
        errorMessage: errorMessage,
        pageSize: pageSize,
        pageToken: pageToken,
        nextPageToken: pagination.nextPageToken,
        memosCount: pagination.memosCount,
      ),
    );
  }

  _PaginationInfo _extractPagination(Object? responseBody) {
    if (responseBody is! Map) {
      return const _PaginationInfo();
    }
    final map = responseBody.cast<String, dynamic>();
    final hasNextTokenKey = map.containsKey('nextPageToken') || map.containsKey('next_page_token');
    final rawNext = map['nextPageToken'] ?? map['next_page_token'];
    final nextToken = hasNextTokenKey ? _parseToken(rawNext, allowEmpty: true) : null;

    int? memosCount = _parseInt(map['memosCount'] ?? map['memos_count']);
    if (memosCount == null) {
      final memos = map['memos'];
      if (memos is List) {
        memosCount = memos.length;
      }
    }

    return _PaginationInfo(nextPageToken: nextToken, memosCount: memosCount);
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String? _parseToken(dynamic value, {bool allowEmpty = false}) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty && !allowEmpty) return null;
      return trimmed;
    }
    if (value is num) return value.toString();
    final text = value.toString().trim();
    if (text.isEmpty && !allowEmpty) return null;
    return text;
  }

  static const _logStartKey = 'log_start';
  static const _logIdKey = 'log_id';
  static const _logMetaKey = 'log_meta';

  String _summarizeResponse(Object? data) {
    if (data == null) return 'null';
    if (data is List<int>) return 'bytes(${data.length})';
    if (data is String) return 'text(${data.length} chars)';
    if (data is List) return 'list(${data.length})';
    if (data is Map) {
      final memosCount = _listCount(data, 'memos') ?? _listCount(data, 'memoList');
      if (memosCount != null) return 'memos=$memosCount';
      final listCount = _listCount(data, 'data');
      if (listCount != null) return 'list=$listCount';
      return 'map(${data.length} keys)';
    }
    return data.runtimeType.toString();
  }

  int? _listCount(Map data, String key) {
    if (!data.containsKey(key)) return null;
    final value = data[key];
    if (value is List) return value.length;
    return null;
  }
}

class _PaginationInfo {
  const _PaginationInfo({this.nextPageToken, this.memosCount});

  final String? nextPageToken;
  final int? memosCount;
}

class _RequestMeta {
  _RequestMeta({
    required this.start,
    required this.method,
    required this.path,
    this.query,
    this.body,
  });

  final DateTime start;
  final String method;
  final String path;
  final String? query;
  final String? body;
}
