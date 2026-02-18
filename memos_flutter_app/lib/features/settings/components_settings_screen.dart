import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../state/image_bed_settings_provider.dart';
import '../../state/location_settings_provider.dart';
import '../../state/memoflow_bridge_settings_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/reminder_scheduler.dart';
import '../../state/reminder_settings_provider.dart';
import '../../state/webdav_settings_provider.dart';
import '../reminders/reminder_settings_screen.dart';
import 'image_bed_settings_screen.dart';
import 'location_settings_screen.dart';
import 'memoflow_bridge_screen.dart';
import 'webdav_sync_screen.dart';
import '../../i18n/strings.g.dart';

class ComponentsSettingsScreen extends ConsumerWidget {
  const ComponentsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final reminderSettings = ref.watch(reminderSettingsProvider);
    final imageBedSettings = ref.watch(imageBedSettingsProvider);
    final locationSettings = ref.watch(locationSettingsProvider);
    final bridgeSettings = ref.watch(memoFlowBridgeSettingsProvider);
    final webDavSettings = ref.watch(webDavSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

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
        title: Text(context.t.strings.legacy.msg_components),
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
              _ToggleCard(
                card: card,
                label: context.t.strings.legacy.msg_memo_reminders_2,
                description:
                    context.t.strings.legacy.msg_enable_reminders_memos,
                value: reminderSettings.enabled,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: (v) async {
                  if (v) {
                    final granted = await _requestReminderPermissions(context);
                    if (!granted) return;
                  }
                  ref.read(reminderSettingsProvider.notifier).setEnabled(v);
                  await ref.read(reminderSchedulerProvider).rescheduleAll();
                },
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReminderSettingsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ToggleCard(
                card: card,
                label: context.t.strings.legacy.msg_third_party_share,
                description: context
                    .t
                    .strings
                    .legacy
                    .msg_allow_sharing_links_images_other_apps,
                value: prefs.thirdPartyShareEnabled,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: (v) => ref
                    .read(appPreferencesProvider.notifier)
                    .setThirdPartyShareEnabled(v),
              ),
              const SizedBox(height: 12),
              _ToggleCard(
                card: card,
                label: context.t.strings.legacy.msg_image_bed_2,
                description: context
                    .t
                    .strings
                    .legacy
                    .msg_upload_images_image_bed_append_links,
                value: imageBedSettings.enabled,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: (v) =>
                    ref.read(imageBedSettingsProvider.notifier).setEnabled(v),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ImageBedSettingsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ToggleCard(
                card: card,
                label: context.t.strings.legacy.msg_location_2,
                description: context
                    .t
                    .strings
                    .legacy
                    .msg_attach_location_info_memos_show_subtle,
                value: locationSettings.enabled,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: (v) =>
                    ref.read(locationSettingsProvider.notifier).setEnabled(v),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LocationSettingsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ToggleCard(
                card: card,
                label: context.t.strings.legacy.msg_webdav_sync,
                description: context
                    .t
                    .strings
                    .legacy
                    .msg_sync_settings_webdav_across_devices,
                value: webDavSettings.enabled,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: (v) =>
                    ref.read(webDavSettingsProvider.notifier).setEnabled(v),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WebDavSyncScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ToggleCard(
                card: card,
                label: context.t.strings.legacy.msg_bridge_component_title,
                description: context.t.strings.legacy.msg_bridge_component_desc,
                value: bridgeSettings.enabled,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: (v) => ref
                    .read(memoFlowBridgeSettingsProvider.notifier)
                    .setEnabled(v),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MemoFlowBridgeScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool> _requestReminderPermissions(BuildContext context) async {
  final confirmed =
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.t.strings.legacy.msg_enable_reminder_permissions),
          content: Text(
            context
                .t
                .strings
                .legacy
                .msg_notification_exact_alarm_permissions_required_send,
          ),
          actions: [
            TextButton(
              onPressed: () => context.safePop(false),
              child: Text(context.t.strings.legacy.msg_cancel_2),
            ),
            FilledButton(
              onPressed: () => context.safePop(true),
              child: Text(context.t.strings.legacy.msg_grant),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed) return false;

  final sdkInt = await _getAndroidSdkInt();
  var notificationStatus = PermissionStatus.granted;
  var exactAlarmStatus = PermissionStatus.granted;
  if (Platform.isAndroid && sdkInt >= 33) {
    notificationStatus = await Permission.notification.request();
  }
  if (Platform.isAndroid && sdkInt >= 31) {
    exactAlarmStatus = await Permission.scheduleExactAlarm.request();
  }
  final granted = notificationStatus.isGranted && exactAlarmStatus.isGranted;
  if (!context.mounted) return granted;
  if (!granted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t.strings.legacy.msg_permissions_denied_reminders_disabled,
        ),
      ),
    );
  }
  return granted;
}

Future<int> _getAndroidSdkInt() async {
  if (!Platform.isAndroid) return 0;
  final info = await DeviceInfoPlugin().androidInfo;
  return info.version.sdkInt;
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.card,
    required this.label,
    required this.description,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
    this.onTap,
  });

  final Color card;
  final String label;
  final String description;
  final bool value;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                  ),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
              if (description.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 44),
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: textMuted,
                      height: 1.3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
