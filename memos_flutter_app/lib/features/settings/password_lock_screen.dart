import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/top_toast.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform/widgets/platform_primary_action.dart';
import '../../state/settings/app_lock_provider.dart';
import '../../i18n/strings.g.dart';
import 'settings_ui.dart';

class PasswordLockScreen extends ConsumerWidget {
  const PasswordLockScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  Future<String?> _showSetPasswordDialog(
    BuildContext context, {
    required bool isChange,
  }) async {
    final password = await showPlatformDialog<String?>(
      context: context,
      builder: (context) => _PasswordDialog(isChange: isChange),
    );

    final trimmed = password?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _selectAutoLockTime(
    BuildContext context,
    WidgetRef ref,
    AutoLockTime selected,
  ) async {
    final next = await showSettingsSingleChoicePicker<AutoLockTime>(
      context: context,
      title: context.t.strings.legacy.msg_auto_lock_time,
      value: selected,
      options: [
        for (final value in AutoLockTime.values)
          SettingsChoiceOption<AutoLockTime>(
            value: value,
            label: value.labelFor(context.appLanguage),
          ),
      ],
    );
    if (next == null) return;
    ref.read(appLockProvider.notifier).setAutoLockTime(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appLockProvider);

    Future<void> setEnabled(bool value) async {
      if (!value) {
        ref.read(appLockProvider.notifier).setEnabled(false);
        return;
      }
      if (!state.hasPassword) {
        final password = await _showSetPasswordDialog(context, isChange: false);
        if (password == null) return;
        if (!context.mounted) return;
        await ref.read(appLockProvider.notifier).setPassword(password);
      }
      if (!context.mounted) return;
      ref.read(appLockProvider.notifier).setEnabled(true);
    }

    return SettingsPage(
      showBackButton: showBackButton,
      title: Text(context.t.strings.legacy.msg_app_lock),
      children: [
        SettingsSection(
          children: [
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_enable_app_lock,
              value: state.enabled,
              onChanged: setEnabled,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          children: [
            SettingsNavigationRow(
              label: context.t.strings.legacy.msg_change_password,
              enabled: state.enabled,
              onTap: () async {
                final password = await _showSetPasswordDialog(
                  context,
                  isChange: true,
                );
                if (password == null) return;
                if (!context.mounted) return;
                await ref.read(appLockProvider.notifier).setPassword(password);
                if (!context.mounted) return;
                showTopToast(
                  context,
                  context.t.strings.legacy.msg_password_updated_local,
                );
              },
            ),
            SettingsNavigationRow(
              label: context.t.strings.legacy.msg_auto_lock_time,
              value: state.autoLockTime.labelFor(context.appLanguage),
              enabled: state.enabled,
              onTap: () =>
                  _selectAutoLockTime(context, ref, state.autoLockTime),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          children: [
            SettingsInfoRow(
              description: context
                  .t
                  .strings
                  .legacy
                  .msg_when_enabled_must_verify_each_app,
            ),
          ],
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.isChange});

  final bool isChange;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  late final TextEditingController _pwdController;
  late final TextEditingController _confirmController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pwdController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _pwdController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final p1 = _pwdController.text.trim();
    final p2 = _confirmController.text.trim();
    if (p1.isEmpty) {
      setState(() => _error = context.t.strings.legacy.msg_enter_password_4);
      return;
    }
    if (p1 != p2) {
      setState(() => _error = context.t.strings.legacy.msg_passwords_not_match);
      return;
    }
    context.safePop(p1);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFormDialog(
      title: Text(
        widget.isChange
            ? context.t.strings.legacy.msg_change_password
            : context.t.strings.legacy.msg_set_password,
      ),
      actions: [
        SettingsDialogAction(
          onPressed: () => context.safePop(null),
          label: Text(context.t.strings.legacy.msg_cancel_2),
        ),
        SettingsDialogAction(
          onPressed: _submit,
          label: Text(context.t.strings.legacy.msg_ok),
          variant: PlatformPrimaryActionVariant.filled,
        ),
      ],
      children: [
        SettingsDialogTextField(
          label: context.t.strings.legacy.msg_password_2,
          controller: _pwdController,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 12),
        SettingsDialogTextField(
          label: context.t.strings.legacy.msg_confirm_password,
          controller: _confirmController,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          SettingsFeedbackRow(
            message: _error!,
            kind: SettingsFeedbackKind.error,
          ),
        ],
      ],
    );
  }
}
