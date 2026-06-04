import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../platform/platform_route.dart';
import '../../state/settings/device_preferences_provider.dart';
import 'export_logs_screen.dart';
import 'self_repair_screen.dart';
import '../../i18n/strings.g.dart';
import 'settings_ui.dart';

class FeedbackScreen extends ConsumerWidget {
  const FeedbackScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
    );
    final tokens = settingsPageTokens(context);

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    return SettingsPage(
      showBackButton: showBackButton,
      title: Text(context.t.strings.legacy.msg_feedback),
      children: [
        SettingsSection(
          footer: Text(
            context.t.strings.legacy.msg_note_some_tokens_returned_only_once,
          ),
          children: [
            SettingsNavigationRow(
              leading: Icon(
                Icons.bug_report_outlined,
                size: 20,
                color: tokens.textMuted,
              ),
              label: context.t.strings.legacy.msg_submit_logs,
              onTap: () {
                haptic();
                Navigator.of(context).push(
                  buildPlatformPageRoute<void>(
                    context: context,
                    builder: (_) => const ExportLogsScreen(),
                  ),
                );
              },
            ),
            SettingsNavigationRow(
              leading: Icon(
                Icons.build_circle_outlined,
                size: 20,
                color: tokens.textMuted,
              ),
              label: context.t.strings.legacy.msg_self_repair,
              description: context.t.strings.legacy.msg_self_repair_subtitle,
              onTap: () {
                haptic();
                Navigator.of(context).push(
                  buildPlatformPageRoute<void>(
                    context: context,
                    builder: (_) => const SelfRepairScreen(),
                  ),
                );
              },
            ),
            SettingsNavigationRow(
              leading: Icon(
                Icons.help_outline,
                size: 20,
                color: tokens.textMuted,
              ),
              label: context.t.strings.legacy.msg_how_report,
              description: 'github.com/hzc073/memoflow/issues/new',
              trailingIcon: Icons.open_in_new,
              onTap: () async {
                haptic();
                final uri = Uri.parse(
                  'https://github.com/hzc073/memoflow/issues/new',
                );
                try {
                  final launched = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.t.strings.legacy.msg_unable_open_browser_try,
                        ),
                      ),
                    );
                  }
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.t.strings.legacy.msg_failed_open_try,
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
