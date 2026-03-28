import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../state/settings/image_bed_settings_provider.dart';
import '../../state/settings/image_compression_settings_provider.dart';
import '../../state/settings/location_settings_provider.dart';
import '../../state/settings/memo_template_settings_provider.dart';
import '../../state/settings/preferences_provider.dart';
import '../../state/system/reminder_scheduler.dart';
import '../../state/settings/reminder_settings_provider.dart';
import '../../state/webdav/webdav_settings_provider.dart';
import '../reminders/reminder_settings_screen.dart';
import 'image_bed_settings_screen.dart';
import 'image_compression_settings_screen.dart';
import 'location_settings_screen.dart';
import 'template_settings_screen.dart';
import 'webdav_sync_screen.dart';
import '../../i18n/strings.g.dart';

class ComponentsSettingsScreen extends ConsumerWidget {
  const ComponentsSettingsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final reminderSettings = ref.watch(reminderSettingsProvider);
    final imageBedSettings = ref.watch(imageBedSettingsProvider);
    final imageCompressionSettings = ref.watch(
      imageCompressionSettingsProvider,
    );
    final locationSettings = ref.watch(locationSettingsProvider);
    final templateSettings = ref.watch(memoTemplateSettingsProvider);
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
        automaticallyImplyLeading: showBackButton,
        leading: showBackButton
            ? IconButton(
                tooltip: context.t.strings.legacy.msg_back,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
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
                onChanged: (nextValue) async {
                  if (!nextValue) {
                    ref
                        .read(appPreferencesProvider.notifier)
                        .setThirdPartyShareEnabled(false);
                    return;
                  }
                  final acknowledged = await _confirmThirdPartyShareEnable(
                    context,
                  );
                  if (!acknowledged) return;
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setThirdPartyShareEnabled(true);
                },
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
                label: context.t.strings.legacy.msg_image_compression,
                description:
                    context.t.strings.legacy.msg_image_compression_desc,
                value: imageCompressionSettings.enabled,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: (v) => ref
                    .read(imageCompressionSettingsProvider.notifier)
                    .setEnabled(v),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ImageCompressionSettingsScreen(),
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
                label: context.t.strings.legacy.msg_template,
                description:
                    context.t.strings.legacy.msg_template_feature_manage_desc,
                value: templateSettings.enabled,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: (v) => ref
                    .read(memoTemplateSettingsProvider.notifier)
                    .setEnabled(v),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TemplateSettingsScreen(),
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
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool> _requestReminderPermissions(BuildContext context) async {
  if (!Platform.isAndroid) return true;

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

Future<bool> _confirmThirdPartyShareEnable(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const ThirdPartyShareCopyrightDialog(),
      ) ??
      false;
}

Future<int> _getAndroidSdkInt() async {
  if (!Platform.isAndroid) return 0;
  final info = await DeviceInfoPlugin().androidInfo;
  return info.version.sdkInt;
}

class ThirdPartyShareCopyrightDialog extends StatefulWidget {
  const ThirdPartyShareCopyrightDialog({super.key});

  @override
  State<ThirdPartyShareCopyrightDialog> createState() =>
      _ThirdPartyShareCopyrightDialogState();
}

class _ThirdPartyShareCopyrightDialogState
    extends State<ThirdPartyShareCopyrightDialog> {
  static const int _initialCountdownSeconds = 5;

  late int _secondsRemaining = _initialCountdownSeconds;
  bool _acknowledged = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
        return;
      }
      setState(() {
        _secondsRemaining -= 1;
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkboxEnabled = _secondsRemaining == 0;

    return AlertDialog(
      title: Text(_thirdPartyShareDialogTitle(context)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _thirdPartyShareDialogBody(context),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _acknowledged,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  _thirdPartyShareAcknowledgeLabel(
                    context,
                    secondsRemaining: _secondsRemaining,
                  ),
                ),
                onChanged: checkboxEnabled
                    ? (checked) {
                        setState(() {
                          _acknowledged = checked ?? false;
                        });
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.safePop(false),
          child: Text(context.t.strings.legacy.msg_cancel_2),
        ),
        FilledButton(
          onPressed: _acknowledged ? () => context.safePop(true) : null,
          child: Text(_thirdPartyShareEnableActionLabel(context)),
        ),
      ],
    );
  }
}

bool _useChineseThirdPartyShareCopy(BuildContext context) {
  final languageCode = Localizations.localeOf(context).languageCode;
  return languageCode.toLowerCase().startsWith('zh');
}

String _thirdPartyShareDialogTitle(BuildContext context) {
  if (_useChineseThirdPartyShareCopy(context)) {
    return '\u4f7f\u7528\u8bf4\u660e';
  }
  return 'Copyright notice';
}

String _thirdPartyShareDialogBody(BuildContext context) {
  if (_useChineseThirdPartyShareCopy(context)) {
    return '\u672c\u529f\u80fd\u4e3a\u7528\u6237\u63d0\u4f9b\u5bf9\u516c\u5f00\u5185\u5bb9\u7684\u4e2a\u4eba\u6574\u7406\u4e0e\u5f15\u7528\u80fd\u529b\uff0c\u76f8\u5173\u5185\u5bb9\u7531\u7528\u6237\u81ea\u884c\u83b7\u53d6\u4e0e\u4f7f\u7528\u3002\n\n\u672c\u5e94\u7528\u4e0d\u53c2\u4e0e\u5185\u5bb9\u7684\u5b58\u50a8\u4e0e\u4f20\u64ad\uff0c\u4e0d\u5bf9\u5185\u5bb9\u7684\u5408\u6cd5\u6027\u4e0e\u5b8c\u6574\u6027\u627f\u62c5\u8d23\u4efb\u3002\n\n\u8bf7\u7528\u6237\u9075\u5b88\u76f8\u5173\u6cd5\u5f8b\u6cd5\u89c4\u53ca\u5e73\u53f0\u89c4\u5219\u4f7f\u7528\u672c\u529f\u80fd\u3002\n\n\u5982\u6709\u4fb5\u6743\u5185\u5bb9\uff0c\u8bf7\u8054\u7cfb\u6211\u4eec\u3002';
  }
  return 'This feature helps users personally organize and cite publicly available content, and the relevant content is obtained and used by users themselves.\n\nThis app does not participate in the storage or distribution of that content and is not responsible for its legality or completeness.\n\nPlease use this feature in compliance with applicable laws, regulations, and platform rules.\n\nIf any content is infringing, please contact us.';
}

String _thirdPartyShareAcknowledgeLabel(
  BuildContext context, {
  required int secondsRemaining,
}) {
  if (_useChineseThirdPartyShareCopy(context)) {
    if (secondsRemaining > 0) {
      return '\u6211\u5df2\u77e5\u6653\uff08$secondsRemaining\u79d2\u540e\u53ef\u52fe\u9009\uff09';
    }
    return '\u6211\u5df2\u77e5\u6653';
  }
  if (secondsRemaining > 0) {
    return 'I understand (${secondsRemaining}s before it can be checked)';
  }
  return 'I understand';
}

String _thirdPartyShareEnableActionLabel(BuildContext context) {
  if (_useChineseThirdPartyShareCopy(context)) {
    return '\u786e\u8ba4\u5f00\u542f';
  }
  return 'Enable';
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
