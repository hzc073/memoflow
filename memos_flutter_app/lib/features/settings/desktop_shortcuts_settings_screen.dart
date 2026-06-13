import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/shortcuts.dart';
import '../../core/top_toast.dart';
import '../../i18n/strings.g.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform/widgets/platform_primary_action.dart';
import '../../state/settings/device_preferences_provider.dart';
import 'settings_ui.dart';

String _desktopShortcutActionLabel(
  BuildContext context,
  DesktopShortcutAction action,
) {
  switch (action) {
    case DesktopShortcutAction.search:
      return context.t.strings.legacy.msg_search;
    case DesktopShortcutAction.quickRecord:
      return context.t.strings.legacy.msg_quick_record;
    case DesktopShortcutAction.quickInput:
      return context.t.strings.legacy.msg_focus_input_area;
    case DesktopShortcutAction.toggleSidebar:
      return context.t.strings.legacy.msg_toggle_sidebar;
    case DesktopShortcutAction.refresh:
      return context.t.strings.legacy.msg_refresh;
    case DesktopShortcutAction.backHome:
      return context.t.strings.legacy.msg_back_home;
    case DesktopShortcutAction.openSettings:
      return context.t.strings.legacy.msg_open_settings;
    case DesktopShortcutAction.enableAppLock:
      return context.t.strings.legacy.msg_enable_app_lock;
    case DesktopShortcutAction.toggleFlomo:
      return context.t.strings.legacy.msg_show_hide_memoflow;
    case DesktopShortcutAction.shortcutOverview:
      return context.t.strings.legacy.msg_shortcuts_overview;
    case DesktopShortcutAction.previousPage:
      return context.t.strings.legacy.msg_previous_page;
    case DesktopShortcutAction.nextPage:
      return context.t.strings.legacy.msg_next_page;
    case DesktopShortcutAction.publishMemo:
      return context.t.strings.legacy.msg_publish_memo;
    case DesktopShortcutAction.bold:
      return context.t.strings.legacy.msg_bold;
    case DesktopShortcutAction.underline:
      return context.t.strings.legacy.msg_underline;
    case DesktopShortcutAction.highlight:
      return context.t.strings.legacy.msg_highlight;
    case DesktopShortcutAction.unorderedList:
      return context.t.strings.legacy.msg_unordered_list;
    case DesktopShortcutAction.orderedList:
      return context.t.strings.legacy.msg_ordered_list;
    case DesktopShortcutAction.undo:
      return context.t.strings.legacy.msg_undo;
    case DesktopShortcutAction.redo:
      return context.t.strings.legacy.msg_redo;
  }
}

class DesktopShortcutsSettingsScreen extends ConsumerWidget {
  const DesktopShortcutsSettingsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  Future<void> _editShortcut(
    BuildContext context,
    WidgetRef ref, {
    required DesktopShortcutAction action,
  }) async {
    final prefs = ref.read(devicePreferencesProvider);
    final current =
        prefs.desktopShortcutBindings[action] ??
        desktopShortcutDefaultBindings[action]!;
    final captured = await _ShortcutCaptureDialog.show(
      context: context,
      action: action,
      current: current,
    );
    if (!context.mounted || captured == null) return;

    final all = ref.read(devicePreferencesProvider).desktopShortcutBindings;
    for (final entry in all.entries) {
      if (entry.key == action) continue;
      if (entry.value == captured) {
        showTopToast(
          context,
          context.t.strings.legacy.msg_shortcut_binding_in_use(
            binding: desktopShortcutBindingLabel(captured),
            action: _desktopShortcutActionLabel(context, entry.key),
          ),
        );
        return;
      }
    }

    ref
        .read(devicePreferencesProvider.notifier)
        .setDesktopShortcutBinding(action: action, binding: captured);
  }

  Widget _buildSection({
    required BuildContext context,
    required WidgetRef ref,
    required List<DesktopShortcutAction> actions,
    required String header,
  }) {
    final bindings = ref.watch(
      devicePreferencesProvider.select((p) => p.desktopShortcutBindings),
    );
    return SettingsSection(
      header: Text(header),
      children: [
        for (final action in actions)
          SettingsValueRow(
            label: _desktopShortcutActionLabel(context, action),
            value: desktopShortcutBindingLabel(
              bindings[action] ?? desktopShortcutDefaultBindings[action]!,
            ),
            description: action == DesktopShortcutAction.publishMemo
                ? context.t.strings.legacy.msg_shift_enter_supported(
                    binding: desktopShiftEnterShortcutLabel(),
                  )
                : null,
            onTap: () => _editShortcut(context, ref, action: action),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = isDesktopShortcutEnabled();
    return SettingsPage(
      showBackButton: showBackButton,
      title: Text(context.t.strings.legacy.msg_shortcuts),
      contentKey: const ValueKey<String>('desktopShortcuts.boundedContent'),
      actions: [
        SettingsAction(
          onPressed: isDesktop
              ? () {
                  ref
                      .read(devicePreferencesProvider.notifier)
                      .resetDesktopShortcutBindings();
                  showTopToast(
                    context,
                    context.t.strings.legacy.msg_default_shortcuts_restored,
                  );
                }
              : null,
          label: Text(context.t.strings.legacy.msg_restore_defaults),
          variant: PlatformPrimaryActionVariant.text,
        ),
      ],
      children: [
        if (!isDesktop)
          SettingsSection(
            children: [
              SettingsInfoRow(
                description: context
                    .t
                    .strings
                    .legacy
                    .msg_shortcuts_supported_windows_macos,
              ),
            ],
          )
        else ...[
          _buildSection(
            context: context,
            ref: ref,
            actions: desktopShortcutGlobalActionsForPlatform(),
            header: context.t.strings.legacy.msg_global,
          ),
          const SizedBox(height: 12),
          _buildSection(
            context: context,
            ref: ref,
            actions: desktopShortcutEditorActions,
            header: context.t.strings.legacy.msg_editor,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SettingsRowDescription(
              context.t.strings.legacy.msg_system_edit_shortcuts_note,
            ),
          ),
        ],
      ],
    );
  }
}

class _ShortcutCaptureDialog extends StatefulWidget {
  const _ShortcutCaptureDialog({required this.action, required this.current});

  final DesktopShortcutAction action;
  final DesktopShortcutBinding current;

  static Future<DesktopShortcutBinding?> show({
    required BuildContext context,
    required DesktopShortcutAction action,
    required DesktopShortcutBinding current,
  }) {
    return showPlatformDialog<DesktopShortcutBinding>(
      context: context,
      builder: (_) => _ShortcutCaptureDialog(action: action, current: current),
    );
  }

  @override
  State<_ShortcutCaptureDialog> createState() => _ShortcutCaptureDialogState();
}

class _ShortcutCaptureDialogState extends State<_ShortcutCaptureDialog> {
  final _focusNode = FocusNode();
  String? _error;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    final captured = desktopShortcutBindingFromKeyEvent(
      event,
      pressedKeys: HardwareKeyboard.instance.logicalKeysPressed,
      requireModifier: false,
    );
    if (captured == null) {
      if (event is KeyDownEvent &&
          !isDesktopShortcutModifierKey(event.logicalKey)) {
        setState(
          () =>
              _error = context.t.strings.legacy.msg_shortcut_requires_modifier(
                modifiers: desktopShortcutModifierLabels().join('/'),
              ),
        );
      }
      return;
    }
    final modifierPressed = captured.primary || captured.shift || captured.alt;
    if (!modifierPressed &&
        !desktopShortcutActionAllowsPlainBinding(
          widget.action,
          captured.logicalKey,
        )) {
      setState(
        () => _error = context.t.strings.legacy.msg_shortcut_requires_modifier(
          modifiers: desktopShortcutModifierLabels().join('/'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(captured);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: SettingsFormDialog(
        title: Text(_desktopShortcutActionLabel(context, widget.action)),
        actions: [
          SettingsDialogAction(
            onPressed: () => Navigator.of(context).maybePop(),
            label: Text(context.t.strings.common.cancel),
          ),
        ],
        children: [
          SettingsRowDescription(
            context.t.strings.legacy.msg_current_shortcut(
              binding: desktopShortcutBindingLabel(widget.current),
            ),
          ),
          const SizedBox(height: 10),
          SettingsRowTitle(context.t.strings.legacy.msg_press_new_shortcut),
          if (_error != null) ...[
            const SizedBox(height: 6),
            SettingsFeedbackRow(
              message: _error!,
              kind: SettingsFeedbackKind.error,
            ),
          ],
        ],
      ),
    );
  }
}
