import 'dart:collection';

import 'package:flutter/painting.dart';

import '../data/logs/log_manager.dart';

const Duration _imageErrorThrottle = Duration(seconds: 20);
const int _maxImageErrorKeys = 240;

final LinkedHashMap<String, DateTime> _recentImageErrorMap =
    LinkedHashMap<String, DateTime>();

void logImageLoadError({
  required String scope,
  required String source,
  required Object error,
  StackTrace? stackTrace,
  Map<String, Object?>? extraContext,
}) {
  final normalizedSource = source.trim();
  final statusCode = _extractStatusCode(error);
  final key = '$scope|$normalizedSource|${error.runtimeType}|${statusCode ?? ''}';
  if (!_shouldLogImageError(key)) return;

  final errorText = error.toString();
  final uri = Uri.tryParse(normalizedSource);
  final context = <String, Object?>{
    'scope': scope,
    'url': normalizedSource,
    'errorType': error.runtimeType.toString(),
    'errorText': _truncate(errorText, 280),
    'hasScheme': uri?.hasScheme ?? false,
    'scheme': uri?.scheme,
    'host': uri?.host,
    'path': uri?.path,
    'isSvg': _looksLikeSvg(normalizedSource, errorText),
    'isFileApi': _looksLikeFileApi(uri),
    'possibleCause': _inferCause(
      normalizedSource: normalizedSource,
      errorText: errorText,
      statusCode: statusCode,
    ),
  };

  if (statusCode != null) {
    context['statusCode'] = statusCode;
  }

  if (stackTrace != null) {
    final top = _firstStackLine(stackTrace);
    if (top.isNotEmpty) {
      context['stackTop'] = top;
    }
  }

  if (extraContext != null && extraContext.isNotEmpty) {
    context.addAll(extraContext);
  }

  LogManager.instance.warn(
    'Image load failed',
    error: error,
    context: context,
  );
}

bool _shouldLogImageError(String key) {
  final now = DateTime.now();
  final last = _recentImageErrorMap[key];
  if (last != null && now.difference(last) < _imageErrorThrottle) {
    return false;
  }
  _recentImageErrorMap.remove(key);
  _recentImageErrorMap[key] = now;
  while (_recentImageErrorMap.length > _maxImageErrorKeys) {
    _recentImageErrorMap.remove(_recentImageErrorMap.keys.first);
  }
  return true;
}

int? _extractStatusCode(Object error) {
  if (error is NetworkImageLoadException) {
    return error.statusCode;
  }
  final text = error.toString();
  final match = RegExp(
    r'(?:status(?:Code)?|http\s*status)\s*[:=]?\s*(\d{3})',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  return int.tryParse(match.group(1) ?? '');
}

bool _looksLikeFileApi(Uri? uri) {
  if (uri == null) return false;
  final segments = uri.pathSegments;
  if (segments.isEmpty) return false;
  return segments.first == 'file';
}

bool _looksLikeSvg(String source, String errorText) {
  final lowerSource = source.toLowerCase();
  if (lowerSource.endsWith('.svg')) return true;
  if (lowerSource.contains('format=svg')) return true;
  final lowerError = errorText.toLowerCase();
  return lowerError.contains('image/svg+xml');
}

String _inferCause({
  required String normalizedSource,
  required String errorText,
  required int? statusCode,
}) {
  if (statusCode != null && statusCode >= 400) {
    return 'http_${statusCode}_non_image_response';
  }

  if (_looksLikeSvg(normalizedSource, errorText)) {
    return 'svg_or_unsupported_format';
  }

  final lower = errorText.toLowerCase();
  if (lower.contains('imagedecoder')) {
    if (lower.contains('unimplemented')) {
      return 'decoder_unimplemented_or_unsupported_image';
    }
    return 'decoder_failed';
  }
  if (lower.contains('input contained an error') ||
      lower.contains('invalid image data')) {
    return 'invalid_or_corrupted_image_bytes';
  }

  return 'unknown';
}

String _firstStackLine(StackTrace trace) {
  final lines = trace.toString().split('\n');
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String _truncate(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...(${text.length} chars)';
}
