import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/top_toast.dart';
import '../../platform/widgets/platform_controls.dart';
import '../../state/maintenance/self_repair_mutation_service.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../i18n/strings.g.dart';
import 'settings_ui.dart';

enum _RepairAction {
  tags,
  search,
  stats;

  IconData get icon => switch (this) {
    _RepairAction.tags => Icons.sell_outlined,
    _RepairAction.search => Icons.manage_search_outlined,
    _RepairAction.stats => Icons.query_stats_outlined,
  };
}

class SelfRepairScreen extends ConsumerStatefulWidget {
  const SelfRepairScreen({super.key});

  @override
  ConsumerState<SelfRepairScreen> createState() => _SelfRepairScreenState();
}

class _SelfRepairScreenState extends ConsumerState<SelfRepairScreen> {
  _RepairAction? _runningAction;

  Future<void> _runAction(_RepairAction action) async {
    if (_runningAction != null) return;
    final confirmed = await _confirmAction(action);
    if (!confirmed || !mounted) return;

    setState(() => _runningAction = action);
    try {
      switch (action) {
        case _RepairAction.tags:
          final service = ref.read(selfRepairMutationServiceProvider);
          await service.repairTagsFromContent();
          break;
        case _RepairAction.search:
          final service = ref.read(selfRepairMutationServiceProvider);
          await service.rebuildSearchIndex();
          break;
        case _RepairAction.stats:
          final service = ref.read(selfRepairMutationServiceProvider);
          await service.rebuildStatsCache();
          break;
      }
      if (!mounted) return;
      showTopToast(context, _resultMessage(context, action));
    } catch (error) {
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_self_repair_failed(e: error),
      );
    } finally {
      if (mounted) {
        setState(() => _runningAction = null);
      }
    }
  }

  Future<bool> _confirmAction(_RepairAction action) async {
    return showSettingsConfirmationDialog(
      context: context,
      title: _confirmTitle(context, action),
      message: _confirmMessage(context, action),
      confirmLabel: context.t.strings.common.confirm,
      cancelLabel: context.t.strings.common.cancel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
    );

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_self_repair),
      children: [
        SettingsSection(
          footer: Text(
            context.t.strings.legacy.msg_self_repair_local_only_note,
          ),
          children: [
            _RepairRow(
              icon: _RepairAction.tags.icon,
              label: context.t.strings.legacy.msg_repair_abnormal_tags,
              subtitle:
                  context.t.strings.legacy.msg_repair_abnormal_tags_subtitle,
              running: _runningAction == _RepairAction.tags,
              disabled:
                  _runningAction != null &&
                  _runningAction != _RepairAction.tags,
              onTap: () {
                haptic();
                _runAction(_RepairAction.tags);
              },
            ),
            _RepairRow(
              icon: _RepairAction.search.icon,
              label: context.t.strings.legacy.msg_rebuild_search_index,
              subtitle:
                  context.t.strings.legacy.msg_rebuild_search_index_subtitle,
              running: _runningAction == _RepairAction.search,
              disabled:
                  _runningAction != null &&
                  _runningAction != _RepairAction.search,
              onTap: () {
                haptic();
                _runAction(_RepairAction.search);
              },
            ),
            _RepairRow(
              icon: _RepairAction.stats.icon,
              label: context.t.strings.legacy.msg_rebuild_stats_cache,
              subtitle:
                  context.t.strings.legacy.msg_rebuild_stats_cache_subtitle,
              running: _runningAction == _RepairAction.stats,
              disabled:
                  _runningAction != null &&
                  _runningAction != _RepairAction.stats,
              onTap: () {
                haptic();
                _runAction(_RepairAction.stats);
              },
            ),
          ],
        ),
      ],
    );
  }
}

String _confirmTitle(BuildContext context, _RepairAction action) {
  return switch (action) {
    _RepairAction.tags =>
      context.t.strings.legacy.msg_confirm_repair_abnormal_tags,
    _RepairAction.search =>
      context.t.strings.legacy.msg_confirm_rebuild_search_index,
    _RepairAction.stats =>
      context.t.strings.legacy.msg_confirm_rebuild_stats_cache,
  };
}

String _confirmMessage(BuildContext context, _RepairAction action) {
  return switch (action) {
    _RepairAction.tags =>
      context.t.strings.legacy.msg_repair_abnormal_tags_confirm_message,
    _RepairAction.search =>
      context.t.strings.legacy.msg_rebuild_search_index_confirm_message,
    _RepairAction.stats =>
      context.t.strings.legacy.msg_rebuild_stats_cache_confirm_message,
  };
}

String _resultMessage(BuildContext context, _RepairAction action) {
  return switch (action) {
    _RepairAction.tags =>
      context.t.strings.legacy.msg_repair_abnormal_tags_success,
    _RepairAction.search =>
      context.t.strings.legacy.msg_rebuild_search_index_success,
    _RepairAction.stats =>
      context.t.strings.legacy.msg_rebuild_stats_cache_success,
  };
}

class _RepairRow extends StatelessWidget {
  const _RepairRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.running,
    required this.disabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool running;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final effectiveMuted = disabled
        ? tokens.textMuted.withValues(alpha: 0.45)
        : tokens.textMuted;
    final effectiveText = disabled
        ? tokens.textMain.withValues(alpha: 0.45)
        : tokens.textMain;
    return SettingsCustomRow(
      leading: Icon(icon, size: 20, color: effectiveMuted),
      title: SettingsRowTitle(label, color: effectiveText),
      description: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: effectiveMuted),
      ),
      trailing: running
          ? SizedBox(width: 18, height: 18, child: PlatformProgress())
          : Icon(Icons.chevron_right, size: 20, color: effectiveMuted),
      onTap: disabled || running ? null : onTap,
      enabled: !disabled,
    );
  }
}
