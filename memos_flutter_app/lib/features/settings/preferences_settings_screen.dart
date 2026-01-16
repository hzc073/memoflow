import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../state/preferences_provider.dart';
import '../../state/theme_mode_provider.dart';

class PreferencesSettingsScreen extends ConsumerWidget {
  const PreferencesSettingsScreen({super.key});

  Future<void> _selectEnum<T>({
    required BuildContext context,
    required String title,
    required List<T> values,
    required String Function(T v) label,
    required T selected,
    required ValueChanged<T> onSelect,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(alignment: Alignment.centerLeft, child: Text(title)),
              ),
              ...values.map((v) {
                final isSelected = v == selected;
                return ListTile(
                  leading: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off),
                  title: Text(label(v)),
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(v);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);

    final themeMode = ref.watch(appThemeModeProvider);
    final themeModeLabel = switch (themeMode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('偏好设置'),
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
                    colors: [
                      const Color(0xFF0B0B0B),
                      bg,
                      bg,
                    ],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _Group(
                card: card,
                divider: divider,
                children: [
              _SelectRow(
                label: '语言',
                value: prefs.language.label,
                icon: Icons.expand_more,
                textMain: textMain,
                textMuted: textMuted,
                onTap: () => _selectEnum<AppLanguage>(
                  context: context,
                  title: '语言',
                  values: AppLanguage.values,
                  label: (v) => v.label,
                  selected: prefs.language,
                  onSelect: (v) => ref.read(appPreferencesProvider.notifier).setLanguage(v),
                ),
              ),
              _SelectRow(
                label: '字号',
                value: prefs.fontSize.label,
                icon: Icons.chevron_right,
                textMain: textMain,
                textMuted: textMuted,
                onTap: () => _selectEnum<AppFontSize>(
                  context: context,
                  title: '字号',
                  values: AppFontSize.values,
                  label: (v) => v.label,
                  selected: prefs.fontSize,
                  onSelect: (v) => ref.read(appPreferencesProvider.notifier).setFontSize(v),
                ),
              ),
              _SelectRow(
                label: '行高',
                value: prefs.lineHeight.label,
                icon: Icons.chevron_right,
                textMain: textMain,
                textMuted: textMuted,
                onTap: () => _selectEnum<AppLineHeight>(
                  context: context,
                  title: '行高',
                  values: AppLineHeight.values,
                  label: (v) => v.label,
                  selected: prefs.lineHeight,
                  onSelect: (v) => ref.read(appPreferencesProvider.notifier).setLineHeight(v),
                ),
              ),
              _ToggleRow(
                label: '使用系统字体',
                value: prefs.useSystemFont,
                textMain: textMain,
                onChanged: (v) => ref.read(appPreferencesProvider.notifier).setUseSystemFont(v),
              ),
              _ToggleRow(
                label: '内容过长折叠',
                value: prefs.collapseLongContent,
                textMain: textMain,
                onChanged: (v) => ref.read(appPreferencesProvider.notifier).setCollapseLongContent(v),
              ),
              _ToggleRow(
                label: '引用/被引用折叠',
                value: prefs.collapseReferences,
                textMain: textMain,
                onChanged: (v) => ref.read(appPreferencesProvider.notifier).setCollapseReferences(v),
              ),
                ],
              ),
              const SizedBox(height: 12),
              _Group(
                card: card,
                divider: divider,
                children: [
              _ToggleRow(
                label: '原图上传',
                value: prefs.uploadOriginalImage,
                textMain: textMain,
                onChanged: (v) => ref.read(appPreferencesProvider.notifier).setUploadOriginalImage(v),
              ),
              _SelectRow(
                label: '启动后立即',
                value: prefs.launchAction.label,
                icon: Icons.expand_more,
                textMain: textMain,
                textMuted: textMuted,
                onTap: () => _selectEnum<LaunchAction>(
                  context: context,
                  title: '启动后立即',
                  values: LaunchAction.values,
                  label: (v) => v.label,
                  selected: prefs.launchAction,
                  onSelect: (v) => ref.read(appPreferencesProvider.notifier).setLaunchAction(v),
                ),
              ),
                ],
              ),
              const SizedBox(height: 12),
              _Group(
                card: card,
                divider: divider,
                children: [
              _SelectRow(
                label: '外观',
                value: themeModeLabel,
                icon: Icons.expand_more,
                textMain: textMain,
                textMuted: textMuted,
                onTap: () => _selectEnum<ThemeMode>(
                  context: context,
                  title: '外观',
                  values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
                  label: (v) => switch (v) {
                    ThemeMode.system => '跟随系统',
                    ThemeMode.light => '浅色',
                    ThemeMode.dark => '深色',
                  },
                  selected: themeMode,
                  onSelect: (v) => ref.read(appThemeModeProvider.notifier).state = v,
                ),
              ),
              _ToggleRow(
                label: '点击震动',
                value: prefs.hapticsEnabled,
                textMain: textMain,
                onChanged: (v) => ref.read(appPreferencesProvider.notifier).setHapticsEnabled(v),
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

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
                ),
              ),
              Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(width: 6),
              Icon(icon, size: 18, color: textMuted),
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
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color textMain;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveTrack = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.12);
    final inactiveThumb = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
            ),
          ),
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
