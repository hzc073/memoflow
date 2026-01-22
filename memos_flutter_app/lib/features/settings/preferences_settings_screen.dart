import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/system_fonts.dart';
import '../../core/theme_colors.dart';
import '../../state/preferences_provider.dart';
import '../../state/system_fonts_provider.dart';

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
                    context.safePop();
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

  Future<void> _selectFont({
    required BuildContext context,
    required WidgetRef ref,
    required AppPreferences prefs,
    required List<SystemFontInfo> fonts,
  }) async {
    final systemDefault = SystemFontInfo(
      family: '',
      displayName: context.tr(zh: '系统默认', en: 'System Default'),
    );
    final selectedFamily = prefs.fontFamily?.trim() ?? '';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(context.tr(zh: '字体', en: 'Font')),
                ),
              ),
              for (final font in [systemDefault, ...fonts])
                ListTile(
                  leading: Icon(
                    font.family == selectedFamily ? Icons.radio_button_checked : Icons.radio_button_off,
                  ),
                  title: Text(font.displayName),
                  onTap: () async {
                    context.safePop();
                    if (font.isSystemDefault) {
                      ref.read(appPreferencesProvider.notifier).setFontFamily(family: null, filePath: null);
                      return;
                    }
                    await SystemFonts.ensureLoaded(font);
                    if (!context.mounted) return;
                    ref.read(appPreferencesProvider.notifier).setFontFamily(
                          family: font.family,
                          filePath: font.filePath,
                        );
                  },
                ),
              if (fonts.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    context.tr(zh: '未找到系统字体', en: 'No system fonts found'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _fontLabel(BuildContext context, AppPreferences prefs, List<SystemFontInfo> fonts) {
    final family = prefs.fontFamily?.trim() ?? '';
    if (family.isEmpty) return context.tr(zh: '系统默认', en: 'System Default');
    for (final font in fonts) {
      if (font.family == family) return font.displayName;
    }
    return family;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);

    final themeMode = prefs.themeMode;
    final themeModeLabel = themeMode.labelFor(prefs.language);
    final themeColor = prefs.themeColor;
    final fontsAsync = ref.watch(systemFontsProvider);
    final fontLabel = _fontLabel(context, prefs, fontsAsync.valueOrNull ?? const []);

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
          tooltip: context.tr(zh: '返回', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr(zh: '偏好设置', en: 'Preferences')),
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
                    label: context.tr(zh: '语言', en: 'Language'),
                    value: prefs.language.labelFor(prefs.language),
                    icon: Icons.expand_more,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _selectEnum<AppLanguage>(
                      context: context,
                      title: context.tr(zh: '语言', en: 'Language'),
                      values: AppLanguage.values,
                      label: (v) => v.labelFor(prefs.language),
                      selected: prefs.language,
                      onSelect: (v) => ref.read(appPreferencesProvider.notifier).setLanguage(v),
                    ),
                  ),
                  _SelectRow(
                    label: context.tr(zh: '字号', en: 'Font Size'),
                    value: prefs.fontSize.labelFor(prefs.language),
                    icon: Icons.chevron_right,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _selectEnum<AppFontSize>(
                      context: context,
                      title: context.tr(zh: '字号', en: 'Font Size'),
                      values: AppFontSize.values,
                      label: (v) => v.labelFor(prefs.language),
                      selected: prefs.fontSize,
                      onSelect: (v) => ref.read(appPreferencesProvider.notifier).setFontSize(v),
                    ),
                  ),
                  _SelectRow(
                    label: context.tr(zh: '行高', en: 'Line Height'),
                    value: prefs.lineHeight.labelFor(prefs.language),
                    icon: Icons.chevron_right,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _selectEnum<AppLineHeight>(
                      context: context,
                      title: context.tr(zh: '行高', en: 'Line Height'),
                      values: AppLineHeight.values,
                      label: (v) => v.labelFor(prefs.language),
                      selected: prefs.lineHeight,
                      onSelect: (v) => ref.read(appPreferencesProvider.notifier).setLineHeight(v),
                    ),
                  ),
                  _SelectRow(
                    label: context.tr(zh: '字体', en: 'Font'),
                    value: fontLabel,
                    icon: Icons.chevron_right,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      try {
                        final List<SystemFontInfo> fonts =
                            fontsAsync.valueOrNull ?? await ref.read(systemFontsProvider.future);
                        if (!context.mounted) return;
                        await _selectFont(context: context, ref: ref, prefs: prefs, fonts: fonts);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.tr(zh: '加载字体失败：$e', en: 'Failed to load fonts: $e'))),
                        );
                      }
                    },
                  ),
                  _ToggleRow(
                    label: context.tr(zh: '折叠长内容', en: 'Collapse Long Content'),
                    value: prefs.collapseLongContent,
                    textMain: textMain,
                    onChanged: (v) => ref.read(appPreferencesProvider.notifier).setCollapseLongContent(v),
                  ),
                  _ToggleRow(
                    label: context.tr(zh: '折叠引用', en: 'Collapse References'),
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
                  _SelectRow(
                    label: context.tr(zh: '启动动作', en: 'Launch Action'),
                    value: prefs.launchAction.labelFor(prefs.language),
                    icon: Icons.expand_more,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _selectEnum<LaunchAction>(
                      context: context,
                      title: context.tr(zh: '启动动作', en: 'Launch Action'),
                      values: LaunchAction.values,
                      label: (v) => v.labelFor(prefs.language),
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
                    label: context.tr(zh: '外观', en: 'Appearance'),
                    value: themeModeLabel,
                    icon: Icons.expand_more,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _selectEnum<AppThemeMode>(
                      context: context,
                      title: context.tr(zh: '外观', en: 'Appearance'),
                      values: const [AppThemeMode.system, AppThemeMode.light, AppThemeMode.dark],
                      label: (v) => v.labelFor(prefs.language),
                      selected: themeMode,
                      onSelect: (v) => ref.read(appPreferencesProvider.notifier).setThemeMode(v),
                    ),
                  ),
                  _ThemeColorRow(
                    label: context.tr(zh: '主题色', en: 'Theme Color'),
                    selected: themeColor,
                    textMain: textMain,
                    isDark: isDark,
                    onSelect: (v) => ref.read(appPreferencesProvider.notifier).setThemeColor(v),
                  ),
                  _ToggleRow(
                    label: context.tr(zh: '触感反馈', en: 'Haptics'),
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

class _ThemeColorRow extends StatelessWidget {
  const _ThemeColorRow({
    required this.label,
    required this.selected,
    required this.textMain,
    required this.isDark,
    required this.onSelect,
  });

  final String label;
  final AppThemeColor selected;
  final Color textMain;
  final bool isDark;
  final ValueChanged<AppThemeColor> onSelect;

  @override
  Widget build(BuildContext context) {
    final ringColor = textMain.withValues(alpha: isDark ? 0.28 : 0.18);

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
          Row(
            children: [
              for (final color in AppThemeColor.values) ...[
                _ThemeColorDot(
                  color: color,
                  selected: color == selected,
                  ringColor: ringColor,
                  onTap: () => onSelect(color),
                ),
                if (color != AppThemeColor.values.last) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeColorDot extends StatelessWidget {
  const _ThemeColorDot({
    required this.color,
    required this.selected,
    required this.ringColor,
    required this.onTap,
  });

  final AppThemeColor color;
  final bool selected;
  final Color ringColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = themeColorSpec(color);
    final fill = spec.primary;
    final size = 22.0;
    final ringPadding = selected ? 2.0 : 0.0;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.all(ringPadding),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: selected ? Border.all(color: ringColor, width: 1.4) : null,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
          ),
          child: selected
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
