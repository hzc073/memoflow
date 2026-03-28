import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/preferences_provider.dart';
import 'migration/memoflow_migration_role_screen.dart';
import 'memoflow_bridge_screen.dart';

class LocalNetworkMigrationScreen extends ConsumerWidget {
  const LocalNetworkMigrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.65);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final hapticsEnabled = ref.watch(
      appPreferencesProvider.select((p) => p.hapticsEnabled),
    );

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.t.strings.legacy.msg_back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.t.strings.legacy.msg_local_network_migration),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFF0B0B0B), bg, bg],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Text(
                context.t.strings.legacy.msg_local_network_migration_desc,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 16),
              _TargetCard(
                card: card,
                border: border,
                textMain: textMain,
                textMuted: textMuted,
                title: context.t.strings.legacy.msg_memoflow_migration,
                subtitle:
                    context.t.strings.legacy.msg_memoflow_migration_target_desc,
                icon: Icons.swap_horiz_rounded,
                onTap: () {
                  haptic();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MemoFlowMigrationRoleScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _TargetCard(
                card: card,
                border: border,
                textMain: textMain,
                textMuted: textMuted,
                title: context.t.strings.legacy.msg_connect_obsidian,
                subtitle: context.t.strings.legacy.msg_connect_obsidian_desc,
                icon: Icons.hub_outlined,
                onTap: () {
                  haptic();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MemoFlowBridgeScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                context
                    .t
                    .strings
                    .legacy
                    .msg_local_network_migration_more_targets,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: textMuted.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.card,
    required this.border,
    required this.textMain,
    required this.textMuted,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final Color card;
  final Color border;
  final Color textMain;
  final Color textMuted;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: MemoFlowPalette.primary.withValues(
                    alpha: isDark ? 0.2 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: MemoFlowPalette.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
