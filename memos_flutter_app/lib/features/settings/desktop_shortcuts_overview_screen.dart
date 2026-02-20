import 'package:flutter/material.dart';

import '../../core/desktop_shortcuts.dart';
import '../../core/memoflow_palette.dart';

class DesktopShortcutsOverviewScreen extends StatelessWidget {
  const DesktopShortcutsOverviewScreen({super.key, required this.bindings});

  final Map<DesktopShortcutAction, DesktopShortcutBinding> bindings;

  @override
  Widget build(BuildContext context) {
    final resolved = normalizeDesktopShortcutBindings(bindings);
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
    final primary = desktopPrimaryShortcutLabel();

    List<Widget> buildRows(List<({String action, String key})> items) {
      return [
        for (var i = 0; i < items.length; i++) ...[
          _OverviewRow(
            action: items[i].action,
            shortcut: items[i].key,
            textMain: textMain,
            textMuted: textMuted,
          ),
          if (i != items.length - 1) Divider(height: 1, color: divider),
        ],
      ];
    }

    final editorItems = <({String action, String key})>[
      (action: '复制', key: '$primary + C'),
      (action: '粘贴', key: '$primary + V'),
      (action: '剪切', key: '$primary + X'),
      for (final action in desktopShortcutEditorActions)
        (
          action: desktopShortcutActionLabel(action),
          key: action == DesktopShortcutAction.publishMemo
              ? '${desktopShortcutBindingLabel(resolved[action]!)} / Shift + 回车'
              : desktopShortcutBindingLabel(resolved[action]!),
        ),
    ];

    final globalItems = <({String action, String key})>[
      for (final action in desktopShortcutGlobalActions)
        (
          action: desktopShortcutActionLabel(action),
          key: action == DesktopShortcutAction.shortcutOverview
              ? '${desktopShortcutBindingLabel(resolved[action]!)} / F1'
              : desktopShortcutBindingLabel(resolved[action]!),
        ),
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('快捷键总览'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
            child: Text(
              '功能 - 快捷键',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textMuted,
              ),
            ),
          ),
          _SectionTitle(title: '编辑器', textMuted: textMuted),
          const SizedBox(height: 8),
          _OverviewGroup(card: card, children: buildRows(editorItems)),
          const SizedBox(height: 12),
          _SectionTitle(title: '全局', textMuted: textMuted),
          const SizedBox(height: 8),
          _OverviewGroup(card: card, children: buildRows(globalItems)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.textMuted});

  final String title;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textMuted,
        ),
      ),
    );
  }
}

class _OverviewGroup extends StatelessWidget {
  const _OverviewGroup({required this.card, required this.children});

  final Color card;
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

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.action,
    required this.shortcut,
    required this.textMain,
    required this.textMuted,
  });

  final String action;
  final String shortcut;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              action,
              style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
            ),
          ),
          Text(
            shortcut,
            style: TextStyle(fontWeight: FontWeight.w600, color: textMuted),
          ),
        ],
      ),
    );
  }
}
