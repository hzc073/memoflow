import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_localization.dart';
import '../../data/models/image_bed_settings.dart';
import '../../data/models/location_settings.dart';
import '../../data/models/webdav_settings.dart';
import '../../state/settings/image_bed_settings_provider.dart';
import '../../state/settings/image_compression_settings_provider.dart';
import '../../state/settings/location_settings_provider.dart';
import '../../state/settings/memo_template_settings_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
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
import 'settings_ui.dart';

class ComponentsSettingsScreen extends ConsumerWidget {
  const ComponentsSettingsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(devicePreferencesProvider);
    final reminderSettings = ref.watch(reminderSettingsProvider);
    final imageBedSettings = ref.watch(imageBedSettingsProvider);
    final imageCompressionSettings = ref.watch(
      imageCompressionSettingsProvider,
    );
    final locationSettings = ref.watch(locationSettingsProvider);
    final templateSettings = ref.watch(memoTemplateSettingsProvider);
    final webDavSettings = ref.watch(webDavSettingsProvider);

    return SettingsPage(
      showBackButton: showBackButton,
      title: Text(context.t.strings.legacy.msg_components),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: SettingsHelpButton(message: _componentsStatusTooltip(context)),
        ),
      ],
      contentKey: const ValueKey<String>('components.boundedContent'),
      children: [
        SettingsFeatureModule(
          title: context.t.strings.legacy.msg_memo_reminders_2,
          tooltip: context.t.strings.legacy.msg_enable_reminders_memos,
          status: _enabledStatus(reminderSettings.enabled),
          value: reminderSettings.enabled,
          onChanged: (v) async {
            if (v) {
              final granted = await _requestReminderPermissions(context);
              if (!granted) return;
            }
            ref.read(reminderSettingsProvider.notifier).setEnabled(v);
            await ref.read(reminderSchedulerProvider).rescheduleAll();
          },
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ReminderSettingsScreen(),
            ),
          ),
        ),
        SettingsFeatureModule(
          title: context.t.strings.legacy.msg_third_party_share,
          tooltip: context
              .t
              .strings
              .legacy
              .msg_allow_sharing_links_images_other_apps,
          status: _enabledStatus(prefs.thirdPartyShareEnabled),
          value: prefs.thirdPartyShareEnabled,
          onChanged: (nextValue) async {
            if (!nextValue) {
              ref
                  .read(devicePreferencesProvider.notifier)
                  .setThirdPartyShareEnabled(false);
              return;
            }
            final acknowledged = await _confirmThirdPartyShareEnable(context);
            if (!acknowledged) return;
            ref
                .read(devicePreferencesProvider.notifier)
                .setThirdPartyShareEnabled(true);
          },
        ),
        SettingsFeatureModule(
          title: context.t.strings.legacy.msg_image_bed_2,
          tooltip:
              context.t.strings.legacy.msg_upload_images_image_bed_append_links,
          status: _configuredStatus(
            enabled: imageBedSettings.enabled,
            configured: _imageBedConfigured(imageBedSettings),
          ),
          value: imageBedSettings.enabled,
          onChanged: (v) =>
              ref.read(imageBedSettingsProvider.notifier).setEnabled(v),
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ImageBedSettingsScreen(),
            ),
          ),
        ),
        SettingsFeatureModule(
          title: context.t.strings.legacy.msg_image_compression,
          tooltip: context.t.strings.legacy.msg_image_compression_desc,
          status: _enabledStatus(imageCompressionSettings.enabled),
          value: imageCompressionSettings.enabled,
          onChanged: (v) =>
              ref.read(imageCompressionSettingsProvider.notifier).setEnabled(v),
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ImageCompressionSettingsScreen(),
            ),
          ),
        ),
        SettingsFeatureModule(
          title: _componentActionLabel(
            context,
            english: 'Location permission',
            chinese: '\u4f4d\u7f6e\u6743\u9650',
          ),
          tooltip: context
              .t
              .strings
              .legacy
              .msg_attach_location_info_memos_show_subtle,
          status: _configuredStatus(
            enabled: locationSettings.enabled,
            configured: _locationConfigured(locationSettings),
          ),
          value: locationSettings.enabled,
          onChanged: (v) =>
              ref.read(locationSettingsProvider.notifier).setEnabled(v),
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const LocationSettingsScreen(),
            ),
          ),
        ),
        SettingsFeatureModule(
          title: _componentActionLabel(
            context,
            english: 'Manage templates',
            chinese: '\u7ba1\u7406\u6a21\u677f',
          ),
          tooltip: context.t.strings.legacy.msg_template_feature_manage_desc,
          status: _enabledStatus(templateSettings.enabled),
          value: templateSettings.enabled,
          onChanged: (v) =>
              ref.read(memoTemplateSettingsProvider.notifier).setEnabled(v),
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TemplateSettingsScreen(),
            ),
          ),
        ),
        SettingsFeatureModule(
          title: _componentActionLabel(
            context,
            english: 'Connection settings (WebDAV Backup)',
            chinese:
                '\u8bbe\u7f6e\u4e0e\u8fde\u63a5\uff08WebDAV \u5907\u4efd\uff09',
          ),
          tooltip:
              context.t.strings.legacy.msg_sync_settings_webdav_across_devices,
          status: _configuredStatus(
            enabled: webDavSettings.enabled,
            configured: _webDavConfigured(webDavSettings),
          ),
          value: webDavSettings.enabled,
          onChanged: (v) =>
              ref.read(webDavSettingsProvider.notifier).setEnabled(v),
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const WebDavSyncScreen()),
          ),
        ),
      ],
    );
  }
}

String _componentsStatusTooltip(BuildContext context) {
  if (_useChineseComponentCopy(context)) {
    return '\u6307\u793a\u706f\u72b6\u6001\uff1a\n'
        '\u7a7a\u5fc3\uff1a\u672a\u914d\u7f6e\n'
        '\u7070\u8272\uff1a\u5df2\u914d\u7f6e\u4f46\u672a\u542f\u7528\n'
        '\u7eff\u8272\uff1a\u5df2\u542f\u7528\u4e14\u72b6\u6001\u6b63\u5e38\n'
        '\u9ec4\u8272\uff1a\u7f3a\u5c11\u6743\u9650\n'
        '\u7ea2\u8272\uff1a\u9519\u8bef\u6216\u5931\u8d25\n'
        '\u95ea\u70c1\u7eff\u8272\uff1a\u6b63\u5728\u5de5\u4f5c';
  }
  return 'Indicator status:\n'
      'Hollow: not configured\n'
      'Gray: configured but disabled\n'
      'Green: enabled and healthy\n'
      'Yellow: permission missing\n'
      'Red: error or failure\n'
      'Blinking green: working';
}

SettingsFeatureStatus _enabledStatus(bool enabled) {
  return enabled
      ? SettingsFeatureStatus.enabledHealthy
      : SettingsFeatureStatus.disabledConfigured;
}

SettingsFeatureStatus _configuredStatus({
  required bool enabled,
  required bool configured,
}) {
  if (!configured) return SettingsFeatureStatus.notConfigured;
  return enabled
      ? SettingsFeatureStatus.enabledHealthy
      : SettingsFeatureStatus.disabledConfigured;
}

bool _imageBedConfigured(ImageBedSettings settings) {
  final hasEndpoint = settings.baseUrl.trim().isNotEmpty;
  final hasToken = settings.authToken?.trim().isNotEmpty ?? false;
  final hasPasswordLogin =
      settings.email.trim().isNotEmpty && settings.password.trim().isNotEmpty;
  return hasEndpoint && (hasToken || hasPasswordLogin);
}

bool _locationConfigured(LocationSettings settings) {
  return switch (settings.provider) {
    LocationServiceProvider.amap =>
      settings.amapWebKey.trim().isNotEmpty &&
          settings.amapSecurityKey.trim().isNotEmpty,
    LocationServiceProvider.baidu => settings.baiduWebKey.trim().isNotEmpty,
    LocationServiceProvider.google => settings.googleApiKey.trim().isNotEmpty,
  };
}

bool _webDavConfigured(WebDavSettings settings) {
  return settings.serverUrl.trim().isNotEmpty &&
      settings.username.trim().isNotEmpty &&
      settings.password.trim().isNotEmpty;
}

String _componentActionLabel(
  BuildContext context, {
  required String english,
  required String chinese,
}) {
  return _useChineseComponentCopy(context) ? chinese : english;
}

bool _useChineseComponentCopy(BuildContext context) {
  final languageCode = Localizations.localeOf(context).languageCode;
  return languageCode.toLowerCase().startsWith('zh');
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
