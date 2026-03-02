import 'package:flutter/material.dart';

import '../../features/memos/memo_detail_screen.dart';
import '../../features/memos/memos_list_screen.dart';
import '../../i18n/strings.g.dart';
import '../../state/reminder_scheduler.dart';

class ReminderTapHandlerImpl {
  const ReminderTapHandlerImpl(this._navigatorKey);

  final GlobalKey<NavigatorState> _navigatorKey;

  Future<void> handle(ReminderTapPayload payload) async {
    final navigator = _navigatorKey.currentState;
    final context = _navigatorKey.currentContext;
    if (navigator == null || context == null) return;

    switch (payload.target) {
      case ReminderTapTarget.memosList:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.strings.legacy.msg_memo_not_found)),
        );
        navigator.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const MemosListScreen(
              title: 'MemoFlow',
              state: 'NORMAL',
              showDrawer: true,
              enableCompose: true,
            ),
          ),
          (route) => false,
        );
        return;
      case ReminderTapTarget.memoDetail:
        final memo = payload.memo;
        if (memo == null) return;
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => MemoDetailScreen(initialMemo: memo),
          ),
        );
        return;
    }
  }
}
