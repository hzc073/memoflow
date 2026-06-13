import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/top_toast.dart';
import '../../core/windows_adaptive_surface.dart';
import '../../data/models/user_setting.dart';
import '../../i18n/strings.g.dart';
import '../../platform/widgets/platform_action_sheet.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/user_settings_provider.dart';
import '../../state/system/session_provider.dart';
import 'settings_ui.dart';

class UserGeneralSettingsScreen extends ConsumerStatefulWidget {
  const UserGeneralSettingsScreen({super.key});

  @override
  ConsumerState<UserGeneralSettingsScreen> createState() =>
      _UserGeneralSettingsScreenState();
}

class _UserGeneralSettingsScreenState
    extends ConsumerState<UserGeneralSettingsScreen> {
  var _saving = false;

  Future<void> _updateSetting(
    UserGeneralSetting current, {
    String? locale,
    String? visibility,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final mask = <String>[];
      if (locale != null) mask.add('locale');
      if (visibility != null) mask.add('memoVisibility');

      final next = current.copyWith(
        locale: locale ?? current.locale,
        memoVisibility: visibility ?? current.memoVisibility,
      );
      final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
      if (account == null) {
        throw StateError('Not authenticated');
      }
      await ref
          .read(memosApiProvider)
          .updateUserGeneralSetting(
            userName: account.user.name,
            setting: next,
            updateMask: mask,
          );
      ref.invalidate(userGeneralSettingProvider);
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_settings_updated);
    } catch (e) {
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_update_failed(e: e));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _selectLocale(UserGeneralSetting current) async {
    final currentLocale = (current.locale ?? '').trim();
    const options = ['', 'en', 'zh-Hans'];
    Widget buildLocalePicker(BuildContext surfaceContext) {
      return SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(surfaceContext.t.strings.legacy.msg_locale),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: Icon(
                  option == currentLocale
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(_localeLabel(option)),
                onTap: () => surfaceContext.safePop(option),
              ),
          ],
        ),
      );
    }

    final result = await _showStringPicker(context, buildLocalePicker);
    if (result == null) return;
    final trimmed = result.trim();
    if (trimmed == currentLocale) return;
    await _updateSetting(current, locale: trimmed);
  }

  Future<void> _selectVisibility(UserGeneralSetting current) async {
    final currentVisibility = (current.memoVisibility ?? '').trim().isNotEmpty
        ? current.memoVisibility!.trim()
        : 'PRIVATE';
    Widget buildVisibilityPicker(BuildContext surfaceContext) {
      return SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  surfaceContext.t.strings.legacy.msg_default_visibility,
                ),
              ),
            ),
            for (final option in const ['PRIVATE', 'PROTECTED', 'PUBLIC'])
              ListTile(
                leading: Icon(
                  option == currentVisibility
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(_visibilityLabel(option)),
                onTap: () => surfaceContext.safePop(option),
              ),
          ],
        ),
      );
    }

    final result = await _showStringPicker(context, buildVisibilityPicker);
    if (result == null || result.trim().isEmpty) return;
    await _updateSetting(current, visibility: result.trim());
  }

  Future<String?> _showStringPicker(
    BuildContext context,
    WidgetBuilder builder,
  ) {
    if (shouldUseWindowsAdaptiveSurface(context)) {
      return showWindowsAdaptiveSurface<String>(
        context: context,
        kind: WindowsAdaptiveSurfaceKind.popover,
        maxWidth: 420,
        builder: builder,
      );
    }
    return showPlatformActionSheet<String>(
      context: context,
      showDragHandle: true,
      builder: builder,
    );
  }

  String _visibilityLabel(String value) {
    switch (value) {
      case 'PUBLIC':
        return context.t.strings.legacy.msg_public;
      case 'PROTECTED':
        return context.t.strings.legacy.msg_protected;
      default:
        return context.t.strings.legacy.msg_private_2;
    }
  }

  String _localeLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return context.t.strings.legacy.msg_default;
    }
    if (normalized == 'en' || normalized.startsWith('en-')) {
      return context.t.strings.legacy.msg_english;
    }
    if (normalized == 'zh-hans' ||
        normalized == 'zh_cn' ||
        normalized == 'zh-cn') {
      return context.t.strings.legacy.msg_chinese_simplified;
    }
    if (normalized == 'zh-hant' ||
        normalized == 'zh_tw' ||
        normalized == 'zh-tw') {
      return context.t.strings.legacy.msg_chinese_traditional;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
    );

    void maybeHaptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    final settingsAsync = ref.watch(userGeneralSettingProvider);

    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_user_general_settings),
      children: [
        settingsAsync.when(
          data: (settings) {
            final locale = (settings.locale ?? '').trim();
            final visibility = (settings.memoVisibility ?? '').trim().isNotEmpty
                ? settings.memoVisibility!.trim()
                : 'PRIVATE';
            final localeLabel = _localeLabel(locale);

            return SettingsSection(
              footer: Text(
                context
                    .t
                    .strings
                    .legacy
                    .msg_these_settings_apply_newly_created_memos,
              ),
              children: [
                SettingsValueRow(
                  label: context.t.strings.legacy.msg_locale,
                  value: localeLabel,
                  enabled: !_saving,
                  onTap: () {
                    maybeHaptic();
                    _selectLocale(settings);
                  },
                ),
                SettingsValueRow(
                  label: context.t.strings.legacy.msg_default_visibility,
                  value: _visibilityLabel(visibility),
                  enabled: !_saving,
                  onTap: () {
                    maybeHaptic();
                    _selectVisibility(settings);
                  },
                ),
              ],
            );
          },
          loading: () => const _UserGeneralLoadingState(),
          error: (error, _) => _UserGeneralErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(userGeneralSettingProvider),
          ),
        ),
      ],
    );
  }
}

class _UserGeneralLoadingState extends StatelessWidget {
  const _UserGeneralLoadingState();

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      children: [
        SettingsProgressRow(label: context.t.strings.legacy.msg_loading),
      ],
    );
  }
}

class _UserGeneralErrorState extends StatelessWidget {
  const _UserGeneralErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          children: [
            SettingsInfoRow(
              description:
                  '${context.t.strings.legacy.msg_failed_load_2}\n$message',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.center,
          child: SettingsAction(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.t.strings.legacy.msg_retry),
          ),
        ),
      ],
    );
  }
}
