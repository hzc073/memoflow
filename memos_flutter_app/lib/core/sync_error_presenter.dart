import '../state/preferences_provider.dart';
import 'app_localization.dart';
import '../application/sync/sync_error.dart';

String presentSyncError({
  required AppLanguage language,
  required SyncError error,
}) {
  final key = error.presentationKey;
  if (key != null && key.trim().isNotEmpty) {
    final params = <String, String>{
      ...?error.presentationParams,
    };
    final prefix = params.remove('prefix');
    if (key == 'legacy.msg_export_path_not_set') {
      final exportLabel = trByLanguageKey(language: language, key: 'legacy.msg_export');
      final pathLabel = trByLanguageKey(language: language, key: 'legacy.msg_path');
      final notSetLabel = trByLanguageKey(language: language, key: 'legacy.msg_not_set');
      var composite = '$exportLabel $pathLabel: $notSetLabel';
      if (prefix != null && prefix.trim().isNotEmpty) {
        composite = '$prefix$composite';
      }
      return composite;
    }
    final baseKey = params.remove('baseKey');
    if (baseKey != null && baseKey.trim().isNotEmpty) {
      params['base'] = trByLanguageKey(language: language, key: baseKey);
    }
    if ((key == 'legacy.msg_sync_failed' ||
            key == 'legacy.msg_local_sync_failed') &&
        !params.containsKey('memoError')) {
      final cause = error.cause;
      if (cause != null) {
        params['memoError'] =
            presentSyncError(language: language, error: cause);
      }
    }
    var resolved = trByLanguageKey(language: language, key: key, params: params);
    if (prefix != null && prefix.trim().isNotEmpty) {
      resolved = '$prefix$resolved';
    }
    return resolved;
  }

  final message = error.message;
  if (message != null && message.trim().isNotEmpty) {
    return message.trim();
  }

  return switch (error.code) {
    SyncErrorCode.invalidConfig => trByLanguageKey(
        language: language,
        key: 'legacy.msg_invalid_request_parameters',
      ),
    SyncErrorCode.authFailed => trByLanguageKey(
        language: language,
        key: 'legacy.msg_authentication_failed_check_token',
      ),
    SyncErrorCode.network => trByLanguageKey(
        language: language,
        key: 'legacy.msg_network_request_failed',
      ),
    SyncErrorCode.server => trByLanguageKey(
        language: language,
        key: 'legacy.msg_server_error',
      ),
    SyncErrorCode.permission => trByLanguageKey(
        language: language,
        key: 'legacy.msg_insufficient_permissions',
      ),
    SyncErrorCode.conflict => trByLanguageKey(
        language: language,
        key: 'legacy.msg_sync_conflicts',
      ),
    SyncErrorCode.dataCorrupt => trByLanguageKey(
        language: language,
        key: 'legacy.webdav.data_corrupted',
      ),
    SyncErrorCode.unknown => trByLanguageKey(
        language: language,
        key: 'legacy.msg_request_failed',
      ),
  };
}

String presentSyncErrorText({
  required AppLanguage language,
  required String raw,
}) {
  final decoded = decodeSyncError(raw);
  if (decoded != null) {
    return presentSyncError(language: language, error: decoded);
  }
  return raw;
}
