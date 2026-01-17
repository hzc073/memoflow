import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/notification_item.dart';
import '../state/memos_providers.dart';
import '../state/session_provider.dart';

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final session = ref.watch(appSessionProvider).valueOrNull;
  final account = session?.currentAccount;
  if (account == null) return const [];

  final api = ref.watch(memosApiProvider);
  final userName = account.user.name;
  final items = <AppNotification>[];
  var pageToken = '';

  for (var page = 0; page < 10; page++) {
    final (batch, nextToken) = await api.listNotifications(
      pageSize: 100,
      pageToken: pageToken.isEmpty ? null : pageToken,
      userName: userName,
    );
    items.addAll(batch);
    if (nextToken.isEmpty) break;
    pageToken = nextToken;
  }

  items.sort((a, b) => b.createTime.compareTo(a.createTime));
  return items;
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final asyncNotifications = ref.watch(notificationsProvider);
  return asyncNotifications.maybeWhen(
    data: (items) => items.where((n) => n.isUnread).length,
    orElse: () => 0,
  );
});
