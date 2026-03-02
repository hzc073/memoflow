import 'package:flutter/material.dart';

import '../../features/memos/memos_list_screen.dart';
import '../../features/review/daily_review_screen.dart';

class AppNavigator {
  const AppNavigator(this._navigatorKey);

  final GlobalKey<NavigatorState> _navigatorKey;

  NavigatorState? get _navigator => _navigatorKey.currentState;

  void openAllMemos() {
    final navigator = _navigator;
    if (navigator == null) return;
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
  }

  void openDailyReview() {
    final navigator = _navigator;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const DailyReviewScreen()),
    );
  }
}
