import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../memos/memos_list_screen.dart';
import '../review/daily_review_screen.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _handledLaunchAction = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleLaunchAction());
  }

  Future<void> _handleLaunchAction() async {
    if (_handledLaunchAction) return;
    _handledLaunchAction = true;

    final prefs = await ref.read(appPreferencesRepositoryProvider).read();

    if (prefs.launchAction == LaunchAction.dailyReview && mounted) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DailyReviewScreen()));
    }

    unawaited(() async {
      final db = ref.read(databaseProvider);
      var hasLocalData = false;
      try {
        hasLocalData = (await db.listMemos(limit: 1)).isNotEmpty;
      } catch (_) {}

      final shouldSync = !hasLocalData || prefs.launchAction == LaunchAction.sync;
      if (shouldSync) {
        unawaited(ref.read(syncControllerProvider.notifier).syncNow());
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    return MemosListScreen(
      title: 'MemoFlow',
      state: 'NORMAL',
      showDrawer: true,
      enableCompose: true,
    );
  }
}
