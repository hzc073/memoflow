import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../core/memoflow_palette.dart';
import '../../data/models/app_preferences.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/system/session_provider.dart';
import '../memos/home_quick_actions.dart';
import '../../i18n/strings.g.dart';

class CustomizeHomeShortcutsScreen extends ConsumerWidget {
  const CustomizeHomeShortcutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(currentWorkspacePreferencesProvider);
    final hasAccount =
        ref.watch(appSessionProvider).valueOrNull?.currentAccount != null;
    final resolvedActions = resolveHomeQuickActions(
      rawPrimary: prefs.homeQuickActionPrimary,
      rawSecondary: prefs.homeQuickActionSecondary,
      rawTertiary: prefs.homeQuickActionTertiary,
      hasAccount: hasAccount,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final slotLabels = [
      context.t.strings.legacy.msg_quick_entry_slot_1,
      context.t.strings.legacy.msg_quick_entry_slot_2,
      context.t.strings.legacy.msg_quick_entry_slot_3,
    ];

    Future<void> pickAction(int index) async {
      final options = buildVisibleHomeQuickActions(hasAccount: hasAccount);
      final selected = await showDialog<HomeQuickAction>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: card,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Text(
              slotLabels[index],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textMain,
              ),
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.6,
              ),
              child: SingleChildScrollView(
                child: RadioGroup<HomeQuickAction>(
                  groupValue: resolvedActions[index],
                  onChanged: (value) {
                    Navigator.of(dialogContext).pop(value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final action in options)
                        RadioListTile<HomeQuickAction>(
                          value: action,
                          enabled: !isHomeQuickActionUsedByOtherSlot(
                            action: action,
                            selectedActions: resolvedActions,
                            editingIndex: index,
                          ),
                          activeColor: MemoFlowPalette.primary,
                          secondary: Icon(
                            homeQuickActionIcon(action),
                            color: homeQuickActionIconColor(
                              action,
                              isDark: isDark,
                            ),
                          ),
                          title: Text(
                            homeQuickActionLabel(dialogContext, action),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
      if (selected == null || selected == resolvedActions[index]) {
        return;
      }

      final next = List<HomeQuickAction>.of(resolvedActions);
      next[index] = selected;
      ref
          .read(currentWorkspacePreferencesProvider.notifier)
          .setHomeQuickActions(
            primary: next[0],
            secondary: next[1],
            tertiary: next[2],
          );
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
        title: Text(context.t.strings.legacy.msg_customize_quick_entries),
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
              _Group(
                card: card,
                divider: divider,
                children: [
                  _ActionRow(
                    label: slotLabels[0],
                    action: resolvedActions[0],
                    textMain: textMain,
                    isDark: isDark,
                    onTap: () => pickAction(0),
                  ),
                  _ActionRow(
                    label: slotLabels[1],
                    action: resolvedActions[1],
                    textMain: textMain,
                    isDark: isDark,
                    onTap: () => pickAction(1),
                  ),
                  _ActionRow(
                    label: slotLabels[2],
                    action: resolvedActions[2],
                    textMain: textMain,
                    isDark: isDark,
                    onTap: () => pickAction(2),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
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
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(height: 1, thickness: 1, color: divider),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.action,
    required this.textMain,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final HomeQuickAction action;
  final Color textMain;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actionLabel = homeQuickActionLabel(context, action);
    final iconColor = homeQuickActionIconColor(action, isDark: isDark);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textMain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(homeQuickActionIcon(action), color: iconColor, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textMain.withValues(alpha: isDark ? 0.82 : 0.76),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: textMain.withValues(alpha: isDark ? 0.42 : 0.48),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
