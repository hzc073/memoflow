import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/strings.g.dart';
import '../../../platform/platform_route.dart';
import '../../../state/settings/device_preferences_provider.dart';
import '../../../state/system/local_library_provider.dart';
import '../settings_ui.dart';
import 'memoflow_migration_receiver_screen.dart';
import 'memoflow_migration_sender_screen.dart';

class MemoFlowMigrationRoleScreen extends ConsumerWidget {
  const MemoFlowMigrationRoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localLibrary = ref.watch(currentLocalLibraryProvider);
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
    );
    final tr = context.t.strings.legacy;

    void haptic() {
      if (hapticsEnabled) HapticFeedback.selectionClick();
    }

    return SettingsPage(
      title: Text(tr.msg_memoflow_migration),
      children: [
        SettingsSection(
          children: [
            SettingsInfoRow(description: tr.msg_memoflow_migration_role_desc),
          ],
        ),
        const SizedBox(height: 14),
        SettingsSection(
          children: [
            SettingsNavigationRow(
              label: tr.msg_memoflow_migration_sender,
              description: localLibrary == null
                  ? tr.msg_memoflow_migration_sender_only_local_mode
                  : tr.msg_memoflow_migration_sender_desc,
              leading: Icon(
                Icons.upload_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              enabled: localLibrary != null,
              onTap: localLibrary == null
                  ? null
                  : () {
                      haptic();
                      Navigator.of(context).push(
                        buildPlatformPageRoute<void>(
                          context: context,
                          builder: (_) => const MemoFlowMigrationSenderScreen(),
                        ),
                      );
                    },
            ),
            SettingsNavigationRow(
              label: tr.msg_memoflow_migration_receiver,
              description: tr.msg_memoflow_migration_receiver_desc,
              leading: Icon(
                Icons.download_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              onTap: () {
                haptic();
                Navigator.of(context).push(
                  buildPlatformPageRoute<void>(
                    context: context,
                    builder: (_) => const MemoFlowMigrationReceiverScreen(),
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
              description: tr.msg_memoflow_migration_foreground_notice,
            ),
          ],
        ),
      ],
    );
  }
}
