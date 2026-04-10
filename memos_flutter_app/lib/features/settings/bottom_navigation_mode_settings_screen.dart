import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../data/models/home_navigation_preferences.dart';
import '../../features/home/home_navigation_resolver.dart';
import '../../features/home/home_root_destination_registry.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/system/session_provider.dart';

class BottomNavigationModeSettingsScreen extends ConsumerWidget {
  const BottomNavigationModeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationPrefs = ref.watch(
      currentWorkspacePreferencesProvider.select(
        (prefs) => prefs.homeNavigationPreferences,
      ),
    );
    final hasAccount =
        ref.watch(appSessionProvider).valueOrNull?.currentAccount != null;
    final resolved = resolveHomeNavigationPreferences(
      navigationPrefs,
      hasAccount: hasAccount,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    Future<void> pickDestination(HomeNavigationSlot slot) async {
      final currentResolved = resolveHomeNavigationPreferences(
        ref.read(currentWorkspacePreferencesProvider).homeNavigationPreferences,
        hasAccount: hasAccount,
      );
      final currentValue = switch (slot) {
        HomeNavigationSlot.leftPrimary => currentResolved.leftPrimary,
        HomeNavigationSlot.leftSecondary => currentResolved.leftSecondary,
        HomeNavigationSlot.rightPrimary => currentResolved.rightPrimary,
        HomeNavigationSlot.rightSecondary => currentResolved.rightSecondary,
      };
      final selected = await showDialog<HomeRootDestination>(
        context: context,
        builder: (dialogContext) {
          final selectedSet = <HomeRootDestination>{
            currentResolved.leftPrimary,
            currentResolved.leftSecondary,
            currentResolved.rightPrimary,
            currentResolved.rightSecondary,
          }..remove(currentValue);
          return AlertDialog(
            backgroundColor: card,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(_slotLabel(context, slot)),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.6,
              ),
              child: SingleChildScrollView(
                child: RadioGroup<HomeRootDestination>(
                  groupValue: currentValue,
                  onChanged: (value) => Navigator.of(dialogContext).pop(value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final destination in kHomeRootDestinationPickerOrder)
                        if (destination == HomeRootDestination.none ||
                            isHomeRootDestinationAvailable(
                              destination,
                              hasAccount: hasAccount,
                            ))
                          RadioListTile<HomeRootDestination>(
                            value: destination,
                            enabled:
                                destination == HomeRootDestination.none ||
                                !selectedSet.contains(destination),
                            activeColor: MemoFlowPalette.primary,
                            secondary: Icon(
                              destination == HomeRootDestination.none
                                  ? Icons.visibility_off_outlined
                                  : homeRootDestinationDefinition(
                                      destination,
                                    )!.icon,
                            ),
                            title: Text(
                              _destinationLabel(dialogContext, destination),
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
      if (selected == null || selected == currentValue) return;
      ref
          .read(currentWorkspacePreferencesProvider.notifier)
          .setHomeNavigationSlot(slot, selected);
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
        title: Text(context.t.strings.legacy.msg_navigation_mode_bottom_bar),
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
              _PreviewCard(resolved: resolved),
              const SizedBox(height: 12),
              _SectionCard(
                card: card,
                divider: divider,
                children: [
                  _DestinationRow(
                    label: _slotLabel(context, HomeNavigationSlot.leftPrimary),
                    destination: resolved.leftPrimary,
                    onTap: () =>
                        pickDestination(HomeNavigationSlot.leftPrimary),
                  ),
                  _DestinationRow(
                    label: _slotLabel(
                      context,
                      HomeNavigationSlot.leftSecondary,
                    ),
                    destination: resolved.leftSecondary,
                    onTap: () =>
                        pickDestination(HomeNavigationSlot.leftSecondary),
                  ),
                  _FixedAddRow(label: context.t.strings.legacy.msg_create_memo),
                  _DestinationRow(
                    label: _slotLabel(context, HomeNavigationSlot.rightPrimary),
                    destination: resolved.rightPrimary,
                    onTap: () =>
                        pickDestination(HomeNavigationSlot.rightPrimary),
                  ),
                  _DestinationRow(
                    label: _slotLabel(
                      context,
                      HomeNavigationSlot.rightSecondary,
                    ),
                    destination: resolved.rightSecondary,
                    onTap: () =>
                        pickDestination(HomeNavigationSlot.rightSecondary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _slotLabel(BuildContext context, HomeNavigationSlot slot) {
    return switch (slot) {
      HomeNavigationSlot.leftPrimary =>
        context.t.strings.legacy.msg_navigation_slot_left_1,
      HomeNavigationSlot.leftSecondary =>
        context.t.strings.legacy.msg_navigation_slot_left_2,
      HomeNavigationSlot.rightPrimary =>
        context.t.strings.legacy.msg_navigation_slot_right_1,
      HomeNavigationSlot.rightSecondary =>
        context.t.strings.legacy.msg_navigation_slot_right_2,
    };
  }

  String _destinationLabel(
    BuildContext context,
    HomeRootDestination destination,
  ) {
    if (destination == HomeRootDestination.none) {
      return context.t.strings.legacy.msg_none;
    }
    return homeRootDestinationDefinition(destination)!.labelBuilder(context);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.label,
    required this.destination,
    required this.onTap,
  });

  final String label;
  final HomeRootDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final definition = homeRootDestinationDefinition(destination);
    final textMain = Theme.of(context).brightness == Brightness.dark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final isNone = destination == HomeRootDestination.none;
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
            Icon(
              isNone ? Icons.visibility_off_outlined : definition!.icon,
              size: 20,
              color: textMain.withValues(alpha: 0.72),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                isNone
                    ? context.t.strings.legacy.msg_none
                    : definition!.labelBuilder(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textMain.withValues(alpha: 0.76),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: textMain.withValues(alpha: 0.48)),
          ],
        ),
      ),
    );
  }
}

class _FixedAddRow extends StatelessWidget {
  const _FixedAddRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final textMain = Theme.of(context).brightness == Brightness.dark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.t.strings.legacy.msg_navigation_slot_center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textMain,
              ),
            ),
          ),
          Icon(Icons.add_circle_outline, color: MemoFlowPalette.primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textMain.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.resolved});

  final ResolvedHomeNavigationPreferences resolved;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? MemoFlowPalette.cardDark
        : Theme.of(context).colorScheme.surface;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    Widget buildItem(HomeRootDestination destination) {
      if (destination == HomeRootDestination.none) {
        return const Expanded(child: SizedBox.shrink());
      }
      final definition = homeRootDestinationDefinition(destination)!;
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(definition.icon, color: MemoFlowPalette.primary, size: 20),
            const SizedBox(height: 4),
            Text(
              definition.labelBuilder(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.strings.legacy.msg_navigation_preview,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              buildItem(resolved.leftPrimary),
              buildItem(resolved.leftSecondary),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle,
                      color: MemoFlowPalette.primary,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t.strings.legacy.msg_create_memo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              buildItem(resolved.rightPrimary),
              buildItem(resolved.rightSecondary),
            ],
          ),
        ],
      ),
    );
  }
}
