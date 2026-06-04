import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/top_toast.dart';
import '../../core/windows_adaptive_surface.dart';
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
    final password = await showDialog<String?>(
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
    AutoLockTime selected, {
    BuildContext? anchorContext,
  }) async {
    Widget buildAutoLockTimeContent(BuildContext surfaceContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(surfaceContext.t.strings.legacy.msg_auto_lock_time),
              ),
            ),
            ...AutoLockTime.values.map((v) {
              final isSelected = v == selected;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(v.labelFor(surfaceContext.appLanguage)),
                onTap: () {
                  surfaceContext.safePop();
                  ref.read(appLockProvider.notifier).setAutoLockTime(v);
                },
              );
            }),
          ],
        ),
      );
    }

    if (shouldUseWindowsAdaptiveSurface(context)) {
      await showWindowsAdaptiveSurface<void>(
        context: context,
        kind: WindowsAdaptiveSurfaceKind.popover,
        anchorContext: anchorContext,
        fallbackAlignment: Alignment.centerRight,
        maxWidth: 360,
        builder: buildAutoLockTimeContent,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: buildAutoLockTimeContent,
    );
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
    return AlertDialog(
      title: Text(
        widget.isChange
            ? context.t.strings.legacy.msg_change_password
            : context.t.strings.legacy.msg_set_password,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pwdController,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.t.strings.legacy.msg_password_2,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.t.strings.legacy.msg_confirm_password,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.safePop(null),
          child: Text(context.t.strings.legacy.msg_cancel_2),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.t.strings.legacy.msg_ok),
        ),
      ],
    );
  }
}
