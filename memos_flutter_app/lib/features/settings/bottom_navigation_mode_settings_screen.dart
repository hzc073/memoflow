import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/home_navigation_preferences.dart';
import '../../features/home/home_navigation_resolver.dart';
import '../../features/home/home_root_destination_registry.dart';
import '../../i18n/strings.g.dart';
import '../../platform/widgets/platform_list_section.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/system/session_provider.dart';
import 'settings_ui.dart';

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
    final tokens = settingsPageTokens(context);

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
      final selectedSet = <HomeRootDestination>{
        currentResolved.leftPrimary,
        currentResolved.leftSecondary,
        currentResolved.rightPrimary,
        currentResolved.rightSecondary,
      }..remove(currentValue);
      final selected =
          await showSettingsSingleChoicePicker<HomeRootDestination>(
            context: context,
            title: _slotLabel(context, slot),
            value: currentValue,
            maxHeightFactor: 0.6,
            options: [
              for (final destination in kHomeRootDestinationPickerOrder)
                if (destination == HomeRootDestination.none ||
                    isHomeRootDestinationAvailable(
                      destination,
                      hasAccount: hasAccount,
                    ))
                  SettingsChoiceOption<HomeRootDestination>(
                    value: destination,
                    label: _destinationLabel(context, destination),
                    icon: destination == HomeRootDestination.none
                        ? Icons.visibility_off_outlined
                        : homeRootDestinationDefinition(destination)!.icon,
                    enabled:
                        destination == HomeRootDestination.none ||
                        !selectedSet.contains(destination),
                    disabledDescription: 'Already used by another slot.',
                  ),
            ],
          );
      if (selected == null || selected == currentValue) return;
      ref
          .read(currentWorkspacePreferencesProvider.notifier)
          .setHomeNavigationSlot(slot, selected);
    }

    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_navigation_mode_bottom_bar),
      children: [
        _PreviewCard(resolved: resolved, tokens: tokens),
        const SizedBox(height: 12),
        SettingsSection(
          children: [
            _DestinationRow(
              label: _slotLabel(context, HomeNavigationSlot.leftPrimary),
              destination: resolved.leftPrimary,
              onTap: () => pickDestination(HomeNavigationSlot.leftPrimary),
            ),
            _DestinationRow(
              label: _slotLabel(context, HomeNavigationSlot.leftSecondary),
              destination: resolved.leftSecondary,
              onTap: () => pickDestination(HomeNavigationSlot.leftSecondary),
            ),
            _FixedAddRow(label: context.t.strings.legacy.msg_create_memo),
            _DestinationRow(
              label: _slotLabel(context, HomeNavigationSlot.rightPrimary),
              destination: resolved.rightPrimary,
              onTap: () => pickDestination(HomeNavigationSlot.rightPrimary),
            ),
            _DestinationRow(
              label: _slotLabel(context, HomeNavigationSlot.rightSecondary),
              destination: resolved.rightSecondary,
              onTap: () => pickDestination(HomeNavigationSlot.rightSecondary),
            ),
          ],
        ),
      ],
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
    final isNone = destination == HomeRootDestination.none;
    return SettingsNavigationRow(
      label: label,
      value: isNone
          ? context.t.strings.legacy.msg_none
          : definition!.labelBuilder(context),
      leading: Icon(
        isNone ? Icons.visibility_off_outlined : definition!.icon,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

class _FixedAddRow extends StatelessWidget {
  const _FixedAddRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final colorScheme = Theme.of(context).colorScheme;
    return PlatformListSectionRow(
      leading: Icon(Icons.add_circle_outline, color: colorScheme.primary),
      title: SettingsRowTitle(
        context.t.strings.legacy.msg_navigation_slot_center,
      ),
      trailing: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: tokens.textMain.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.resolved, required this.tokens});

  final ResolvedHomeNavigationPreferences resolved;
  final SettingsPageTokens tokens;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outlineVariant.withValues(alpha: 0.65);

    Widget buildItem(HomeRootDestination destination) {
      if (destination == HomeRootDestination.none) {
        return const Expanded(child: SizedBox.shrink());
      }
      final definition = homeRootDestinationDefinition(destination)!;
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(definition.icon, color: colorScheme.primary, size: 20),
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
        color: tokens.card,
        borderRadius: BorderRadius.circular(8),
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
                      color: colorScheme.primary,
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
