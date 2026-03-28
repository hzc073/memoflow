import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/memoflow_palette.dart';
import '../../../i18n/strings.g.dart';
import '../../../state/settings/preferences_provider.dart';
import '../../../state/system/local_library_provider.dart';
import 'memoflow_migration_receiver_screen.dart';
import 'memoflow_migration_sender_screen.dart';

class MemoFlowMigrationRoleScreen extends ConsumerWidget {
  const MemoFlowMigrationRoleScreen({super.key});

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
    final localLibrary = ref.watch(currentLocalLibraryProvider);
    final hapticsEnabled = ref.watch(
      appPreferencesProvider.select((p) => p.hapticsEnabled),
    );
    final tr = context.t.strings.legacy;

    void haptic() {
      if (hapticsEnabled) HapticFeedback.selectionClick();
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(tr.msg_memoflow_migration),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Text(
            tr.msg_memoflow_migration_role_desc,
            style: TextStyle(fontSize: 12.5, height: 1.45, color: textMuted),
          ),
          const SizedBox(height: 16),
          _RoleCard(
            card: card,
            border: border,
            textMain: textMain,
            textMuted: textMuted,
            icon: Icons.upload_outlined,
            title: tr.msg_memoflow_migration_sender,
            subtitle: localLibrary == null
                ? tr.msg_memoflow_migration_sender_only_local_mode
                : tr.msg_memoflow_migration_sender_desc,
            enabled: localLibrary != null,
            onTap: localLibrary == null
                ? null
                : () {
                    haptic();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MemoFlowMigrationSenderScreen(),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 12),
          _RoleCard(
            card: card,
            border: border,
            textMain: textMain,
            textMuted: textMuted,
            icon: Icons.download_outlined,
            title: tr.msg_memoflow_migration_receiver,
            subtitle: tr.msg_memoflow_migration_receiver_desc,
            enabled: true,
            onTap: () {
              haptic();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MemoFlowMigrationReceiverScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            tr.msg_memoflow_migration_foreground_notice,
            style: TextStyle(fontSize: 12, height: 1.4, color: textMuted),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.card,
    required this.border,
    required this.textMain,
    required this.textMuted,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final Color card;
  final Color border;
  final Color textMain;
  final Color textMuted;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.6,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MemoFlowPalette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: MemoFlowPalette.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
