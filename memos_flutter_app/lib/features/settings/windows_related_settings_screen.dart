import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../state/preferences_provider.dart';
import 'desktop_shortcuts_settings_screen.dart';

class WindowsRelatedSettingsScreen extends ConsumerWidget {
  const WindowsRelatedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: '\u8fd4\u56de',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Windows\u76f8\u5173\u8bbe\u7f6e'),
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
          if (!Platform.isWindows)
            Center(
              child: Text(
                '\u4ec5 Windows \u684c\u9762\u652f\u6301\u6b64\u8bbe\u7f6e\u3002',
                style: TextStyle(color: textMuted, fontWeight: FontWeight.w600),
              ),
            )
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                _Group(
                  card: card,
                  divider: divider,
                  children: [
                    _ActionRow(
                      label: '\u5feb\u6377\u952e\u8bbe\u7f6e',
                      subtitle:
                          '\u914d\u7f6e Windows \u684c\u9762\u5feb\u6377\u952e',
                      textMain: textMain,
                      textMuted: textMuted,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const DesktopShortcutsSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _ToggleRow(
                      label:
                          '\u5173\u95ed\u7a97\u53e3\u65f6\u6700\u5c0f\u5316\u5230\u6258\u76d8',
                      subtitle:
                          '\u542f\u7528\u540e\u70b9\u51fb\u53f3\u4e0a\u89d2\u5173\u95ed\u6309\u94ae\u4e0d\u4f1a\u9000\u51fa\u5e94\u7528\uff0c\u53ef\u5728\u7cfb\u7edf\u6258\u76d8\u6062\u590d\u7a97\u53e3\u3002',
                      value: prefs.windowsCloseToTray,
                      textMain: textMain,
                      textMuted: textMuted,
                      onChanged: notifier.setWindowsCloseToTray,
                    ),
                  ],
                ),
              ],
            ),
        ],
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
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, color: divider),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right, size: 20, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveTrack = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.12);
    final inactiveThumb = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: MemoFlowPalette.primary,
            inactiveTrackColor: inactiveTrack,
            inactiveThumbColor: inactiveThumb,
          ),
        ],
      ),
    );
  }
}
