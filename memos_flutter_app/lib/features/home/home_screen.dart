import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../memos/memos_list_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef _ref) {
    return MemosListScreen(
      title: 'MemoFlow',
      state: 'NORMAL',
      showDrawer: true,
      enableCompose: true,
    );
  }
}
