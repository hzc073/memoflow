import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_provider.dart';

final memoEditorDraftRepositoryProvider = Provider<MemoEditorDraftRepository>((
  ref,
) {
  final accountKey = ref.watch(
    appSessionProvider.select((state) => state.valueOrNull?.currentKey),
  );
  return MemoEditorDraftRepository(
    ref.watch(secureStorageProvider),
    accountKey: accountKey,
  );
});

class MemoEditorDraftRepository {
  MemoEditorDraftRepository(this._storage, {required String? accountKey})
    : _accountKey = accountKey;

  static const _kPrefix = 'memo_editor_draft_v1_';

  final FlutterSecureStorage _storage;
  final String? _accountKey;

  String _sanitizeKeyPart(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'empty';
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _storageKey(String memoUid) {
    final scope = _sanitizeKeyPart(_accountKey ?? 'local');
    final memo = _sanitizeKeyPart(memoUid);
    return '$_kPrefix${scope}_$memo';
  }

  Future<String> read({required String memoUid}) async {
    final uid = memoUid.trim();
    if (uid.isEmpty) return '';
    final raw = await _storage.read(key: _storageKey(uid));
    return raw ?? '';
  }

  Future<void> write({required String memoUid, required String text}) async {
    final uid = memoUid.trim();
    if (uid.isEmpty) return;
    if (text.trim().isEmpty) {
      await clear(memoUid: uid);
      return;
    }
    await _storage.write(key: _storageKey(uid), value: text);
  }

  Future<void> clear({required String memoUid}) async {
    final uid = memoUid.trim();
    if (uid.isEmpty) return;
    await _storage.delete(key: _storageKey(uid));
  }
}
