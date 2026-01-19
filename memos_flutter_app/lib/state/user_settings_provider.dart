import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/shortcut.dart';
import '../data/models/user_setting.dart';
import 'memos_providers.dart';
import 'session_provider.dart';

final userGeneralSettingProvider = FutureProvider<UserGeneralSetting>((ref) async {
  final api = ref.watch(memosApiProvider);
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    throw StateError('Not authenticated');
  }
  return api.getUserGeneralSetting(userName: account.user.name);
});

final userWebhooksProvider = FutureProvider<List<UserWebhook>>((ref) async {
  final api = ref.watch(memosApiProvider);
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    throw StateError('Not authenticated');
  }
  return api.listUserWebhooks(userName: account.user.name);
});

final shortcutsProvider = FutureProvider<List<Shortcut>>((ref) async {
  final api = ref.watch(memosApiProvider);
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    throw StateError('Not authenticated');
  }
  return api.listShortcuts(userName: account.user.name);
});
