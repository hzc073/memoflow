import 'package:flutter/material.dart';

import '../../features/explore/explore_screen.dart';
import '../../features/home/home_entry_screen.dart';
import '../../features/review/daily_review_screen.dart';

class AppNavigator {
  const AppNavigator(this._navigatorKey);

  final GlobalKey<NavigatorState> _navigatorKey;

  NavigatorState? get _navigator => _navigatorKey.currentState;

  void openAllMemos() {
    final navigator = _navigator;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeEntryScreen()),
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

  void openExplore() {
    final navigator = _navigator;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const ExploreScreen()),
    );
  }

  void openDayMemos(DateTime day) {
    final navigator = _navigator;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil(
      '/memos/day',
      (route) => false,
      arguments: day,
    );
  }
}
