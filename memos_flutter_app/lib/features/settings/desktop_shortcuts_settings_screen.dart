import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/shortcuts.dart';
import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/device_preferences_provider.dart';

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
  const DesktopShortcutsSettingsScreen({super.key});

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
    required Color card,
    required Color divider,
    required Color textMain,
    required Color textMuted,
  }) {
    final bindings = ref.watch(
      devicePreferencesProvider.select((p) => p.desktopShortcutBindings),
    );
    return _Group(
      card: card,
      divider: divider,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          _ShortcutRow(
            label: _desktopShortcutActionLabel(context, actions[i]),
            value: desktopShortcutBindingLabel(
              bindings[actions[i]] ??
                  desktopShortcutDefaultBindings[actions[i]]!,
            ),
            caption: actions[i] == DesktopShortcutAction.publishMemo
                ? context.t.strings.legacy.msg_shift_enter_supported
                : null,
            textMain: textMain,
            textMuted: textMuted,
            onTap: () => _editShortcut(context, ref, action: actions[i]),
          ),
          if (i != actions.length - 1) Divider(height: 1, color: divider),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = isDesktopShortcutEnabled();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: resolveDesktopRouteAutomaticallyImplyLeading(
          context: context,
          automaticallyImplyLeading: true,
        ),
        leading: resolveDesktopRouteDismissalLeading(
          context: context,
          leading: IconButton(
            tooltip: context.t.strings.common.back,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(context.t.strings.legacy.msg_shortcuts),
        centerTitle: false,
        actions: [
          TextButton(
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
            child: Text(context.t.strings.legacy.msg_restore_defaults),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (!isDesktop)
            _Group(
              card: card,
              divider: divider,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context
                        .t
                        .strings
                        .legacy
                        .msg_shortcuts_supported_windows_macos,
                    style: TextStyle(color: textMuted, height: 1.35),
                  ),
                ),
              ],
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
              child: Text(
                context.t.strings.legacy.msg_global,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                ),
              ),
            ),
            _buildSection(
              context: context,
              ref: ref,
              actions: desktopShortcutGlobalActionsForPlatform(),
              card: card,
              divider: divider,
              textMain: textMain,
              textMuted: textMuted,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
              child: Text(
                context.t.strings.legacy.msg_editor,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                ),
              ),
            ),
            _buildSection(
              context: context,
              ref: ref,
              actions: desktopShortcutEditorActions,
              card: card,
              divider: divider,
              textMain: textMain,
              textMuted: textMuted,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                context.t.strings.legacy.msg_system_edit_shortcuts_note,
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ),
          ],
        ],
      ),
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
    return showDialog<DesktopShortcutBinding>(
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
              _error = context.t.strings.legacy.msg_shortcut_requires_modifier,
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
        () => _error = context.t.strings.legacy.msg_shortcut_requires_modifier,
      );
      return;
    }
    Navigator.of(context).pop(captured);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _desktopShortcutActionLabel(context, widget.action),
                style: TextStyle(fontWeight: FontWeight.w800, color: textMain),
              ),
              const SizedBox(height: 8),
              Text(
                context.t.strings.legacy.msg_current_shortcut(
                  binding: desktopShortcutBindingLabel(widget.current),
                ),
                style: TextStyle(color: textMuted),
              ),
              const SizedBox(height: 10),
              Text(
                context.t.strings.legacy.msg_press_new_shortcut,
                style: TextStyle(color: textMain, fontWeight: FontWeight.w600),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(context.t.strings.common.cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.card,
    required this.divider,
    required this.children,
  });

  final Color card;
  final Color divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
      child: Column(children: children),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textMain,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        caption!,
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w600, color: textMuted),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
