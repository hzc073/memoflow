import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop_shortcuts.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../i18n/strings.g.dart';
import '../../state/preferences_provider.dart';

class DesktopShortcutsSettingsScreen extends ConsumerWidget {
  const DesktopShortcutsSettingsScreen({super.key});

  Future<void> _editShortcut(
    BuildContext context,
    WidgetRef ref, {
    required DesktopShortcutAction action,
  }) async {
    final prefs = ref.read(appPreferencesProvider);
    final current =
        prefs.desktopShortcutBindings[action] ??
        desktopShortcutDefaultBindings[action]!;
    final captured = await _ShortcutCaptureDialog.show(
      context: context,
      action: action,
      current: current,
    );
    if (!context.mounted || captured == null) return;

    final all = ref.read(appPreferencesProvider).desktopShortcutBindings;
    for (final entry in all.entries) {
      if (entry.key == action) continue;
      if (entry.value == captured) {
        showTopToast(
          context,
          '${desktopShortcutBindingLabel(captured)} 已被「${desktopShortcutActionLabel(entry.key)}」占用。',
        );
        return;
      }
    }

    ref
        .read(appPreferencesProvider.notifier)
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
      appPreferencesProvider.select((p) => p.desktopShortcutBindings),
    );
    return _Group(
      card: card,
      divider: divider,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          _ShortcutRow(
            label: desktopShortcutActionLabel(actions[i]),
            value: desktopShortcutBindingLabel(
              bindings[actions[i]] ??
                  desktopShortcutDefaultBindings[actions[i]]!,
            ),
            caption: actions[i] == DesktopShortcutAction.publishMemo
                ? '同时支持 Shift + 回车'
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
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
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
        leading: IconButton(
          tooltip: context.t.strings.common.back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('快捷键'),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: isDesktop
                ? () {
                    ref
                        .read(appPreferencesProvider.notifier)
                        .resetDesktopShortcutBindings();
                    showTopToast(context, '已恢复默认快捷键。');
                  }
                : null,
            child: const Text('恢复默认'),
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
                    '仅 Windows 和 macOS 支持快捷键设置。',
                    style: TextStyle(color: textMuted, height: 1.35),
                  ),
                ),
              ],
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
              child: Text(
                '全局',
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
              actions: desktopShortcutGlobalActions,
              card: card,
              divider: divider,
              textMain: textMain,
              textMuted: textMuted,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
              child: Text(
                '编辑器',
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
            if (isWindows) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  'Windows \u7ffb\u9875\uff1aPageUp \u4e0a\u4e00\u9875\uff0cPageDown \u4e0b\u4e00\u9875\u3002',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '复制 / 粘贴 / 剪切使用系统默认快捷键。',
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
      requireModifier: true,
    );
    if (captured == null) {
      if (event is KeyDownEvent &&
          !isDesktopShortcutModifierKey(event.logicalKey)) {
        setState(() => _error = '请至少包含一个修饰键（Ctrl/Cmd/Shift/Alt）。');
      }
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
                desktopShortcutActionLabel(widget.action),
                style: TextStyle(fontWeight: FontWeight.w800, color: textMain),
              ),
              const SizedBox(height: 8),
              Text(
                '当前：${desktopShortcutBindingLabel(widget.current)}',
                style: TextStyle(color: textMuted),
              ),
              const SizedBox(height: 10),
              Text(
                '请按下新的快捷键…',
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
