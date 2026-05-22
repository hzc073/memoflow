import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../core/memoflow_palette.dart';
import '../../state/maintenance/self_repair_mutation_service.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../i18n/strings.g.dart';

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
    final service = ref.read(selfRepairMutationServiceProvider);
    try {
      switch (action) {
        case _RepairAction.tags:
          await service.repairTagsFromContent();
          break;
        case _RepairAction.search:
          await service.rebuildSearchIndex();
          break;
        case _RepairAction.stats:
          await service.rebuildStatsCache();
          break;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_successMessage(context, action))));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_self_repair_failed(e: error),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _runningAction = null);
      }
    }
  }

  Future<bool> _confirmAction(_RepairAction action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_confirmTitle(context, action)),
        content: Text(_confirmMessage(context, action)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t.strings.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.t.strings.common.confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
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
        automaticallyImplyLeading: resolveDesktopRouteAutomaticallyImplyLeading(
          context: context,
          automaticallyImplyLeading: true,
        ),
        leading: resolveDesktopRouteDismissalLeading(
          context: context,
          leading: IconButton(
            tooltip: context.t.strings.legacy.msg_back,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(context.t.strings.legacy.msg_self_repair),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _RepairRow(
                    icon: _RepairAction.tags.icon,
                    label: context.t.strings.legacy.msg_repair_abnormal_tags,
                    subtitle: context
                        .t
                        .strings
                        .legacy
                        .msg_repair_abnormal_tags_subtitle,
                    running: _runningAction == _RepairAction.tags,
                    disabled:
                        _runningAction != null &&
                        _runningAction != _RepairAction.tags,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      _runAction(_RepairAction.tags);
                    },
                  ),
                  _RepairRow(
                    icon: _RepairAction.search.icon,
                    label: context.t.strings.legacy.msg_rebuild_search_index,
                    subtitle: context
                        .t
                        .strings
                        .legacy
                        .msg_rebuild_search_index_subtitle,
                    running: _runningAction == _RepairAction.search,
                    disabled:
                        _runningAction != null &&
                        _runningAction != _RepairAction.search,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      _runAction(_RepairAction.search);
                    },
                  ),
                  _RepairRow(
                    icon: _RepairAction.stats.icon,
                    label: context.t.strings.legacy.msg_rebuild_stats_cache,
                    subtitle: context
                        .t
                        .strings
                        .legacy
                        .msg_rebuild_stats_cache_subtitle,
                    running: _runningAction == _RepairAction.stats,
                    disabled:
                        _runningAction != null &&
                        _runningAction != _RepairAction.stats,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      _runAction(_RepairAction.stats);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.t.strings.legacy.msg_self_repair_local_only_note,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: textMuted.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ],
      ),
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

String _successMessage(BuildContext context, _RepairAction action) {
  return switch (action) {
    _RepairAction.tags =>
      context.t.strings.legacy.msg_repair_abnormal_tags_success,
    _RepairAction.search =>
      context.t.strings.legacy.msg_rebuild_search_index_success,
    _RepairAction.stats =>
      context.t.strings.legacy.msg_rebuild_stats_cache_success,
  };
}

class _CardGroup extends StatelessWidget {
  const _CardGroup({
    required this.card,
    required this.divider,
    required this.children,
  });

  final Color card;
  final Color divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
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
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, color: divider),
          ],
        ],
      ),
    );
  }
}

class _RepairRow extends StatelessWidget {
  const _RepairRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.running,
    required this.disabled,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool running;
  final bool disabled;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveMuted = disabled
        ? textMuted.withValues(alpha: 0.45)
        : textMuted;
    final effectiveText = disabled
        ? textMain.withValues(alpha: 0.45)
        : textMain;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled || running ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: effectiveMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: effectiveText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: effectiveMuted),
                    ),
                  ],
                ),
              ),
              if (running)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: effectiveMuted,
                  ),
                )
              else
                Icon(Icons.chevron_right, size: 20, color: effectiveMuted),
            ],
          ),
        ),
      ),
    );
  }
}
