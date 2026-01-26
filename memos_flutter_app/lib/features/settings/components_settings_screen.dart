import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../state/preferences_provider.dart';
import '../../state/reminder_scheduler.dart';
import '../../state/reminder_settings_provider.dart';
import '../reminders/reminder_settings_screen.dart';

class ComponentsSettingsScreen extends ConsumerWidget {
  const ComponentsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final reminderSettings = ref.watch(reminderSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.tr(zh: '返回', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr(zh: '功能组件', en: 'Components')),
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
                    colors: [
                      const Color(0xFF0B0B0B),
                      bg,
                      bg,
                    ],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _ToggleCard(
                card: card,
                label: context.tr(zh: '笔记提醒', en: 'Memo reminders'),
                description: context.tr(
                  zh: '开启后可为笔记设置提醒时间。',
                  en: 'Enable reminders for your memos.',
                ),
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
                  MaterialPageRoute<void>(builder: (_) => const ReminderSettingsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _ToggleCard(
                card: card,
                label: context.tr(zh: '第三方分享', en: 'Third-party Share'),
                description: context.tr(
                  zh: '允许从其他应用分享链接或图片到 MemoFlow。',
                  en: 'Allow sharing links or images from other apps into MemoFlow.',
                ),
                value: prefs.thirdPartyShareEnabled,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: (v) =>
                    ref.read(appPreferencesProvider.notifier).setThirdPartyShareEnabled(v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool> _requestReminderPermissions(BuildContext context) async {
  final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr(zh: '启用提醒权限', en: 'Enable reminder permissions')),
          content: Text(
            context.tr(
              zh: '需要通知权限与精确闹钟权限，才能在指定时间发送提醒。',
              en: 'Notification and exact alarm permissions are required to send reminders on time.',
            ),
          ),
          actions: [
            TextButton(onPressed: () => context.safePop(false), child: Text(context.tr(zh: '取消', en: 'Cancel'))),
            FilledButton(
              onPressed: () => context.safePop(true),
              child: Text(context.tr(zh: '去授权', en: 'Grant')),
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
      SnackBar(content: Text(context.tr(zh: '权限未授予，提醒未开启', en: 'Permissions denied. Reminders disabled.'))),
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
                    child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
                  ),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
              if (description.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 44),
                  child: Text(
                    description,
                    style: TextStyle(fontSize: 12, color: textMuted, height: 1.3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
