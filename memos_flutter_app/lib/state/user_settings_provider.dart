import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/shortcut.dart';
import '../data/models/user_setting.dart';
import '../data/settings/local_shortcuts_repository.dart';
import 'memos_providers.dart';
import 'session_provider.dart';

final userGeneralSettingProvider = FutureProvider<UserGeneralSetting>((
  ref,
) async {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    return const UserGeneralSetting();
  }
  final api = ref.watch(memosApiProvider);
  return api.getUserGeneralSetting(userName: account.user.name);
});

final userWebhooksProvider = FutureProvider<List<UserWebhook>>((ref) async {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    return const <UserWebhook>[];
  }
  final api = ref.watch(memosApiProvider);
  return api.listUserWebhooks(userName: account.user.name);
});

final localShortcutsRepositoryProvider = Provider<LocalShortcutsRepository>((
  ref,
) {
  final session = ref.watch(appSessionProvider).valueOrNull;
  final key = session?.currentKey?.trim();
  final accountKey = (key == null || key.isEmpty) ? 'device' : key;
  return LocalShortcutsRepository(
    ref.watch(secureStorageProvider),
    accountKey: accountKey,
  );
});

final shortcutsProvider = FutureProvider<List<Shortcut>>((ref) async {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    return const <Shortcut>[];
  }
  final api = ref.watch(memosApiProvider);
  await api.ensureServerHintsLoaded();
  if (api.usesLegacySearchFilterDialect ||
      api.shortcutsSupportedHint == false) {
    return ref.read(localShortcutsRepositoryProvider).read();
  }
  return api.listShortcuts(userName: account.user.name);
});
