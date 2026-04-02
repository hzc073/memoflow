import 'package:dio/dio.dart';

import '../../application/sync/sync_error.dart';
import '../../data/db/app_database.dart';
import '../../data/models/local_memo.dart';

const int remoteMemoMaxCharsDefault = 8192;

typedef MemoSyncMutationPolicy = ({
  bool allowRemoteSync,
  String? lastError,
  int syncState,
});

int? tryParseRemoteMemoLengthLimit(Object errorOrRawText) {
  final normalized = _normalizeRemoteMemoErrorText(errorOrRawText);
  if (normalized.isEmpty) return null;
  for (final pattern in <RegExp>[
    RegExp(
      r'max(?:imum)?\s*(?:length\s*)?(?:is\s*)?(\d+)',
      caseSensitive: false,
    ),
    RegExp(r'(\d+)\s*characters', caseSensitive: false),
    RegExp(r'limit(?:ed)?\s*(?:to\s*)?(\d+)', caseSensitive: false),
  ]) {
    final match = pattern.firstMatch(normalized);
    final parsed = match == null ? null : int.tryParse(match.group(1) ?? '');
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }
  return null;
}

bool looksLikeRemoteMemoTooLongError(Object errorOrRawText) {
  final normalized = _normalizeRemoteMemoErrorText(
    errorOrRawText,
  ).toLowerCase();
  if (normalized.isEmpty) return false;
  return normalized.contains('content too long') ||
      normalized.contains('exceeds the maximum') ||
      normalized.contains('maximum length') ||
      normalized.contains('memo too long') ||
      (normalized.contains('limit') && normalized.contains('characters'));
}

String buildRemoteMemoTooLongUserMessage({
  int? maxChars,
  bool includeFallback = true,
}) {
  final primary = maxChars != null && maxChars > 0
      ? 'The current server limit is $maxChars characters. Increase the server memo length limit and retry.'
      : 'This server limits memo length. Increase the server memo length limit and retry.';
  if (!includeFallback) {
    return primary;
  }
  return '$primary If you cannot change the server, shorten this memo and retry.';
}

Future<bool> guardMemoContentForRemoteSync({
  required AppDatabase db,
  required bool enabled,
  required String memoUid,
  required String content,
}) async {
  final normalizedMemoUid = memoUid.trim();
  if (normalizedMemoUid.isEmpty) return true;
  if (!await shouldAllowMemoRemoteSync(db: db, memoUid: normalizedMemoUid)) {
    return false;
  }
  if (!enabled) return true;
  db.hashCode;
  content.length;
  return true;
}

MemoSyncMutationPolicy resolveMemoSyncMutationPolicy({
  required String? currentLastError,
  int syncStateWhenRemoteSyncAllowed = 1,
  String? lastErrorWhenRemoteSyncAllowed,
}) {
  final normalizedLastError = currentLastError?.trim();
  if (isLocalOnlySyncPausedError(normalizedLastError)) {
    return (
      allowRemoteSync: false,
      lastError: normalizedLastError,
      syncState: SyncState.error.index,
    );
  }
  return (
    allowRemoteSync: true,
    lastError: lastErrorWhenRemoteSyncAllowed,
    syncState: syncStateWhenRemoteSyncAllowed,
  );
}

Future<bool> shouldAllowMemoRemoteSync({
  required AppDatabase db,
  required String memoUid,
}) async {
  final normalizedMemoUid = memoUid.trim();
  if (normalizedMemoUid.isEmpty) return true;
  final row = await db.getMemoByUid(normalizedMemoUid);
  final currentLastError = row?['last_error'] as String?;
  return !isLocalOnlySyncPausedError(currentLastError);
}

String _normalizeRemoteMemoErrorText(Object value) {
  final parts = <String>[];
  void addPart(Object? part) {
    final text = part?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      parts.add(text);
    }
  }

  addPart(value);
  if (value is DioException) {
    addPart(value.message);
    addPart(value.error);
    addPart(_extractDioErrorMessage(value.response?.data));
  }
  return parts.join(' | ');
}

String? _extractDioErrorMessage(Object? data) {
  if (data == null) return null;
  if (data is String) return data;
  if (data is Map) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
  }
  return data.toString();
}
