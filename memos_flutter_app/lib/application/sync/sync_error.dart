import 'dart:convert';

enum SyncErrorCode {
  invalidConfig,
  authFailed,
  network,
  server,
  permission,
  conflict,
  dataCorrupt,
  unknown,
}

class SyncError implements Exception {
  const SyncError({
    required this.code,
    required this.retryable,
    this.message,
    this.httpStatus,
    this.requestMethod,
    this.requestPath,
    this.presentationKey,
    this.presentationParams,
    this.cause,
  });

  final SyncErrorCode code;
  final bool retryable;
  final String? message;
  final int? httpStatus;
  final String? requestMethod;
  final String? requestPath;
  final String? presentationKey;
  final Map<String, String>? presentationParams;
  final SyncError? cause;

  SyncError copyWith({
    SyncErrorCode? code,
    bool? retryable,
    String? message,
    int? httpStatus,
    String? requestMethod,
    String? requestPath,
    String? presentationKey,
    Map<String, String>? presentationParams,
    SyncError? cause,
  }) {
    return SyncError(
      code: code ?? this.code,
      retryable: retryable ?? this.retryable,
      message: message ?? this.message,
      httpStatus: httpStatus ?? this.httpStatus,
      requestMethod: requestMethod ?? this.requestMethod,
      requestPath: requestPath ?? this.requestPath,
      presentationKey: presentationKey ?? this.presentationKey,
      presentationParams: presentationParams ?? this.presentationParams,
      cause: cause ?? this.cause,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'code': code.name,
      'retryable': retryable,
      if (message != null) 'message': message,
      if (httpStatus != null) 'httpStatus': httpStatus,
      if (requestMethod != null) 'requestMethod': requestMethod,
      if (requestPath != null) 'requestPath': requestPath,
      if (presentationKey != null) 'presentationKey': presentationKey,
      if (presentationParams != null) 'presentationParams': presentationParams,
      if (cause != null) 'cause': cause!.toJson(),
    };
  }

  static SyncError? fromJson(Map<String, Object?> json) {
    final rawCode = json['code'];
    if (rawCode is! String) return null;
    final parsedCode = SyncErrorCode.values
        .where((c) => c.name == rawCode)
        .cast<SyncErrorCode?>()
        .firstWhere((c) => c != null, orElse: () => null);
    if (parsedCode == null) return null;
    final retryable = json['retryable'] == true;
    final message = json['message'] as String?;
    final httpStatusRaw = json['httpStatus'];
    final httpStatus = httpStatusRaw is int
        ? httpStatusRaw
        : (httpStatusRaw is num ? httpStatusRaw.toInt() : null);
    final requestMethod = json['requestMethod'] as String?;
    final requestPath = json['requestPath'] as String?;
    final presentationKey = json['presentationKey'] as String?;
    final presentationParamsRaw = json['presentationParams'];
    Map<String, String>? presentationParams;
    if (presentationParamsRaw is Map) {
      presentationParams = presentationParamsRaw.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    }
    SyncError? cause;
    final causeRaw = json['cause'];
    if (causeRaw is Map) {
      cause = SyncError.fromJson(causeRaw.cast<String, Object?>());
    }
    return SyncError(
      code: parsedCode,
      retryable: retryable,
      message: message,
      httpStatus: httpStatus,
      requestMethod: requestMethod,
      requestPath: requestPath,
      presentationKey: presentationKey,
      presentationParams: presentationParams,
      cause: cause,
    );
  }

  @override
  String toString() {
    final parts = <String>[
      'code=${code.name}',
      'retryable=$retryable',
      if (httpStatus != null) 'http=$httpStatus',
      if (requestMethod != null && requestPath != null)
        '${requestMethod!} $requestPath',
      if (message != null && message!.trim().isNotEmpty) message!,
    ];
    return 'SyncError(${parts.join(', ')})';
  }
}

const String kSyncErrorPrefix = 'SYNC_ERROR:';

String encodeSyncError(SyncError error) {
  return '$kSyncErrorPrefix${jsonEncode(error.toJson())}';
}

SyncError? decodeSyncError(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (!trimmed.startsWith(kSyncErrorPrefix)) return null;
  final payload = trimmed.substring(kSyncErrorPrefix.length);
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map) {
      return SyncError.fromJson(decoded.cast<String, Object?>());
    }
  } catch (_) {}
  return null;
}
