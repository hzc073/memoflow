import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../core/memoflow_palette.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/device_preferences_provider.dart';
import 'desktop_shortcuts_settings_screen.dart';

class WindowsRelatedSettingsScreen extends ConsumerWidget {
  const WindowsRelatedSettingsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

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
    final prefs = ref.watch(devicePreferencesProvider);
    final notifier = ref.read(devicePreferencesProvider.notifier);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: resolveDesktopRouteAutomaticallyImplyLeading(
          context: context,
          automaticallyImplyLeading: showBackButton,
        ),
        leading: resolveDesktopRouteDismissalLeading(
          context: context,
          leading: showBackButton
              ? IconButton(
                  tooltip: context.t.strings.common.back,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null,
        ),
        title: Text(context.t.strings.legacy.msg_windows_related_settings),
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
                context
                    .t
                    .strings
                    .legacy
                    .msg_only_windows_desktop_supports_this_setting,
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
                      label: context.t.strings.legacy.msg_shortcut_settings,
                      subtitle: context
                          .t
                          .strings
                          .legacy
                          .msg_configure_windows_desktop_shortcuts,
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
                      label: context
                          .t
                          .strings
                          .legacy
                          .msg_close_window_minimize_to_tray,
                      subtitle: context
                          .t
                          .strings
                          .legacy
                          .msg_close_window_minimize_to_tray_desc,
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
