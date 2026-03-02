import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/sync/webdav_vault_service.dart';
import '../data/settings/webdav_vault_password_repository.dart';
import '../data/settings/webdav_vault_recovery_repository.dart';
import '../data/settings/webdav_vault_state_repository.dart';
import 'session_provider.dart';

final webDavVaultPasswordRepositoryProvider =
    Provider<WebDavVaultPasswordRepository>((ref) {
  final accountKey = ref.watch(
    appSessionProvider.select((state) => state.valueOrNull?.currentKey),
  );
  return WebDavVaultPasswordRepository(
    ref.watch(secureStorageProvider),
    accountKey: accountKey,
  );
});

final webDavVaultRecoveryRepositoryProvider =
    Provider<WebDavVaultRecoveryRepository>((ref) {
  final accountKey = ref.watch(
    appSessionProvider.select((state) => state.valueOrNull?.currentKey),
  );
  return WebDavVaultRecoveryRepository(
    ref.watch(secureStorageProvider),
    accountKey: accountKey,
  );
});

final webDavVaultStateRepositoryProvider =
    Provider<WebDavVaultStateRepository>((ref) {
  final accountKey = ref.watch(
    appSessionProvider.select((state) => state.valueOrNull?.currentKey),
  );
  return WebDavVaultStateRepository(
    ref.watch(secureStorageProvider),
    accountKey: accountKey,
  );
});

final webDavVaultServiceProvider = Provider<WebDavVaultService>((ref) {
  return WebDavVaultService();
});
