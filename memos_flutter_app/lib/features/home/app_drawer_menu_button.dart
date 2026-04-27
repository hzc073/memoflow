import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_motion_widgets.dart';
import '../../state/memos/sync_queue_provider.dart';
import '../../state/system/notifications_provider.dart';

class AppDrawerMenuButton extends ConsumerWidget {
  const AppDrawerMenuButton({
    super.key,
    required this.tooltip,
    required this.iconColor,
    required this.badgeBorderColor,
    this.onPressed,
  });

  final String tooltip;
  final Color iconColor;
  final Color badgeBorderColor;
  final VoidCallback? onPressed;

  static const _badgeColor = Color(0xFFE05555);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadNotificationCount = ref.watch(unreadNotificationCountProvider);
    final pendingCountAsync = ref.watch(syncQueuePendingCountProvider);
    final pendingCount = pendingCountAsync.valueOrNull ?? 0;
    final attentionCountAsync = ref.watch(syncQueueAttentionCountProvider);
    final attentionCount = attentionCountAsync.valueOrNull ?? 0;
    final showBadge =
        unreadNotificationCount > 0 || pendingCount > 0 || attentionCount > 0;

    return AppPressScale(
      child: IconButton(
        key: const ValueKey('drawer-menu-button'),
        tooltip: tooltip,
        onPressed:
            onPressed ??
            () {
              final scaffold = Scaffold.maybeOf(context);
              if (scaffold?.hasDrawer ?? false) {
                scaffold!.openDrawer();
              }
            },
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.menu, color: iconColor),
            if (showBadge)
              PositionedDirectional(
                top: 2,
                end: 2,
                child: Container(
                  key: const ValueKey('drawer-menu-badge'),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: badgeBorderColor, width: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
