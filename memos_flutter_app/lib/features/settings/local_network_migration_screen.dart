import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../i18n/strings.g.dart';
import '../../platform/platform_route.dart';
import '../../state/settings/device_preferences_provider.dart';
import 'migration/memoflow_migration_role_screen.dart';
import 'memoflow_bridge_screen.dart';
import 'settings_ui.dart';

const _memoFlowMigrationIconAsset =
    'assets/images/migration/memoflow_migration.svg';
const _obsidianMigrationIconAsset =
    'assets/images/migration/obsidian_migration.svg';

class LocalNetworkMigrationScreen extends ConsumerWidget {
  const LocalNetworkMigrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
    );
    final tr = context.t.strings.legacy;

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    return SettingsPage(
      title: Text(tr.msg_local_network_migration),
      children: [
        SettingsSection(
          children: [
            SettingsInfoRow(description: tr.msg_local_network_migration_desc),
          ],
        ),
        const SizedBox(height: 14),
        SettingsSection(
          children: [
            SettingsNavigationRow(
              label: tr.msg_memoflow_migration,
              description: tr.msg_memoflow_migration_target_desc,
              leading: SvgPicture.asset(
                _memoFlowMigrationIconAsset,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
              onTap: () {
                haptic();
                Navigator.of(context).push(
                  buildPlatformPageRoute<void>(
                    context: context,
                    builder: (_) => const MemoFlowMigrationRoleScreen(),
                  ),
                );
              },
            ),
            SettingsNavigationRow(
              label: tr.msg_connect_obsidian,
              description: tr.msg_connect_obsidian_desc,
              leading: SvgPicture.asset(
                _obsidianMigrationIconAsset,
                width: 24,
                height: 24,
              ),
              onTap: () {
                haptic();
                Navigator.of(context).push(
                  buildPlatformPageRoute<void>(
                    context: context,
                    builder: (_) => const MemoFlowBridgeScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsSection(
          children: [
            SettingsInfoRow(
              description: tr.msg_local_network_migration_more_targets,
            ),
          ],
        ),
      ],
    );
  }
}
