import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../core/system_fonts.dart';
import '../../core/theme_colors.dart';
import '../../i18n/strings.g.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title),
                ),
              ),
              ...values.map((v) {
                final isSelected = v == selected;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
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
      displayName: context.t.strings.settings.preferences.systemDefault,
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
                  child: Text(context.t.strings.settings.preferences.font),
                ),
              ),
              for (final font in [systemDefault, ...fonts])
                ListTile(
                  leading: Icon(
                    font.family == selectedFamily
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(font.displayName),
                  onTap: () async {
                    context.safePop();
                    if (font.isSystemDefault) {
                      ref
                          .read(appPreferencesProvider.notifier)
                          .setFontFamily(family: null, filePath: null);
                      return;
                    }
                    await SystemFonts.ensureLoaded(font);
                    if (!context.mounted) return;
                    ref
                        .read(appPreferencesProvider.notifier)
                        .setFontFamily(
                          family: font.family,
                          filePath: font.filePath,
                        );
                  },
                ),
              if (fonts.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    context.t.strings.settings.preferences.noSystemFonts,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _fontLabel(
    BuildContext context,
    AppPreferences prefs,
    List<SystemFontInfo> fonts,
  ) {
    final family = prefs.fontFamily?.trim() ?? '';
    if (family.isEmpty) {
      return context.t.strings.settings.preferences.systemDefault;
    }
    for (final font in fonts) {
      if (font.family == family) return font.displayName;
    }
    return family;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final session = ref.watch(appSessionProvider).valueOrNull;
    final accountKey = session?.currentKey;

    final themeMode = prefs.themeMode;
    final themeModeLabel = themeMode.labelFor(prefs.language);
    final themeColor = prefs.resolveThemeColor(accountKey);
    final customTheme = prefs.resolveCustomTheme(accountKey);
    final fontsAsync = ref.watch(systemFontsProvider);
    final fontLabel = _fontLabel(
      context,
      prefs,
      fontsAsync.valueOrNull ?? const [],
    );

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
    final languageItems = AppLanguage.values
        .map(
          (language) => DropdownMenuItem<AppLanguage>(
            value: language,
            child: Text(
              language.labelFor(prefs.language),
              style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
            ),
          ),
        )
        .toList(growable: false);

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
        title: Text(context.t.strings.settings.preferences.title),
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
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _Group(
                card: card,
                divider: divider,
                children: [
                  _DropdownRow<AppLanguage>(
                    label: context.t.strings.settings.preferences.language,
                    value: prefs.language,
                    items: languageItems,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (v) {
                      if (v == null) return;
                      ref.read(appPreferencesProvider.notifier).setLanguage(v);
                    },
                  ),
                  _SelectRow(
                    label: context.t.strings.settings.preferences.fontSize,
                    value: prefs.fontSize.labelFor(prefs.language),
                    icon: Icons.chevron_right,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _selectEnum<AppFontSize>(
                      context: context,
                      title: context.t.strings.settings.preferences.fontSize,
                      values: AppFontSize.values,
                      label: (v) => v.labelFor(prefs.language),
                      selected: prefs.fontSize,
                      onSelect: (v) => ref
                          .read(appPreferencesProvider.notifier)
                          .setFontSize(v),
                    ),
                  ),
                  _SelectRow(
                    label: context.t.strings.settings.preferences.lineHeight,
                    value: prefs.lineHeight.labelFor(prefs.language),
                    icon: Icons.chevron_right,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _selectEnum<AppLineHeight>(
                      context: context,
                      title: context.t.strings.settings.preferences.lineHeight,
                      values: AppLineHeight.values,
                      label: (v) => v.labelFor(prefs.language),
                      selected: prefs.lineHeight,
                      onSelect: (v) => ref
                          .read(appPreferencesProvider.notifier)
                          .setLineHeight(v),
                    ),
                  ),
                  _SelectRow(
                    label: context.t.strings.settings.preferences.font,
                    value: fontLabel,
                    icon: Icons.chevron_right,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      try {
                        final List<SystemFontInfo> fonts =
                            fontsAsync.valueOrNull ??
                            await ref.read(systemFontsProvider.future);
                        if (!context.mounted) return;
                        await _selectFont(
                          context: context,
                          ref: ref,
                          prefs: prefs,
                          fonts: fonts,
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.t.strings.settings.preferences
                                  .loadFontsFailed(error: e.toString()),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  _ToggleRow(
                    label: context
                        .t
                        .strings
                        .settings
                        .preferences
                        .collapseLongContent,
                    value: prefs.collapseLongContent,
                    textMain: textMain,
                    onChanged: (v) => ref
                        .read(appPreferencesProvider.notifier)
                        .setCollapseLongContent(v),
                  ),
                  _ToggleRow(
                    label: context
                        .t
                        .strings
                        .settings
                        .preferences
                        .collapseReferences,
                    value: prefs.collapseReferences,
                    textMain: textMain,
                    onChanged: (v) => ref
                        .read(appPreferencesProvider.notifier)
                        .setCollapseReferences(v),
                  ),
                  _ToggleRow(
                    label: context
                        .t
                        .strings
                        .settings
                        .preferences
                        .showEngagementInAllMemoDetails,
                    value: prefs.showEngagementInAllMemoDetails,
                    textMain: textMain,
                    onChanged: (v) => ref
                        .read(appPreferencesProvider.notifier)
                        .setShowEngagementInAllMemoDetails(v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Group(
                card: card,
                divider: divider,
                children: [
                  _SelectRow(
                    label: context.t.strings.settings.preferences.launchAction,
                    value: prefs.launchAction.labelFor(prefs.language),
                    icon: Icons.expand_more,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _selectEnum<LaunchAction>(
                      context: context,
                      title:
                          context.t.strings.settings.preferences.launchAction,
                      values: LaunchAction.values
                          .where((v) => v != LaunchAction.sync)
                          .toList(growable: false),
                      label: (v) => v.labelFor(prefs.language),
                      selected: prefs.launchAction,
                      onSelect: (v) => ref
                          .read(appPreferencesProvider.notifier)
                          .setLaunchAction(v),
                    ),
                  ),
                  _ToggleRow(
                    label: context
                        .t
                        .strings
                        .settings
                        .preferences
                        .quickInputKeyboard,
                    value: prefs.quickInputAutoFocus,
                    textMain: textMain,
                    onChanged: (v) => ref
                        .read(appPreferencesProvider.notifier)
                        .setQuickInputAutoFocus(v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Group(
                card: card,
                divider: divider,
                children: [
                  _SelectRow(
                    label: context.t.strings.settings.preferences.appearance,
                    value: themeModeLabel,
                    icon: Icons.expand_more,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _selectEnum<AppThemeMode>(
                      context: context,
                      title: context.t.strings.settings.preferences.appearance,
                      values: const [
                        AppThemeMode.system,
                        AppThemeMode.light,
                        AppThemeMode.dark,
                      ],
                      label: (v) => v.labelFor(prefs.language),
                      selected: themeMode,
                      onSelect: (v) => ref
                          .read(appPreferencesProvider.notifier)
                          .setThemeMode(v),
                    ),
                  ),
                  _ThemeColorRow(
                    label: context.t.strings.settings.preferences.themeColor,
                    selected: themeColor,
                    textMain: textMain,
                    isDark: isDark,
                    onSelect: (v) => ref
                        .read(appPreferencesProvider.notifier)
                        .setThemeColorForAccount(
                          accountKey: accountKey,
                          color: v,
                        ),
                    onCustomTap: () async {
                      final next = await CustomThemeDialog.show(
                        context: context,
                        initial: customTheme,
                      );
                      if (next == null || !context.mounted) return;
                      final notifier = ref.read(
                        appPreferencesProvider.notifier,
                      );
                      notifier.setCustomThemeForAccount(
                        accountKey: accountKey,
                        settings: next,
                      );
                      notifier.setThemeColorForAccount(
                        accountKey: accountKey,
                        color: AppThemeColor.custom,
                      );
                    },
                  ),
                  _ToggleRow(
                    label: context.t.strings.settings.preferences.haptics,
                    value: prefs.hapticsEnabled,
                    textMain: textMain,
                    onChanged: (v) => ref
                        .read(appPreferencesProvider.notifier)
                        .setHapticsEnabled(v),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w600, color: textMuted),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 18, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isDense: true,
              icon: Icon(Icons.expand_more, size: 18, color: textMuted),
              style: TextStyle(fontWeight: FontWeight.w600, color: textMuted),
              dropdownColor: Theme.of(context).cardColor,
            ),
          ),
        ],
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
    final inactiveTrack = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.12);
    final inactiveThumb = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.white;

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
    required this.onCustomTap,
  });

  final String label;
  final AppThemeColor selected;
  final Color textMain;
  final bool isDark;
  final ValueChanged<AppThemeColor> onSelect;
  final VoidCallback onCustomTap;

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
                if (color == AppThemeColor.custom)
                  _CustomThemeColorDot(
                    selected: color == selected,
                    ringColor: ringColor,
                    onTap: onCustomTap,
                  )
                else
                  _ThemeColorDot(
                    color: color,
                    selected: color == selected,
                    ringColor: ringColor,
                    onTap: () => onSelect(color),
                  ),
                if (color != AppThemeColor.values.last)
                  const SizedBox(width: 10),
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
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: selected
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class _CustomThemeColorDot extends StatelessWidget {
  const _CustomThemeColorDot({
    required this.selected,
    required this.ringColor,
    required this.onTap,
  });

  final bool selected;
  final Color ringColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 22.0;
    final ringPadding = selected ? 2.0 : 0.0;
    const gradient = SweepGradient(
      colors: [
        Color(0xFFE55B5B),
        Color(0xFFF2C879),
        Color(0xFF7BB98A),
        Color(0xFF5FB1C2),
        Color(0xFF5E7CE0),
        Color(0xFFB36BD3),
        Color(0xFFE55B5B),
      ],
    );

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
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
          ),
          child: Icon(
            selected ? Icons.check : Icons.add,
            size: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class CustomThemeDialog extends StatefulWidget {
  const CustomThemeDialog({super.key, required this.initial});

  final CustomThemeSettings initial;

  static Future<CustomThemeSettings?> show({
    required BuildContext context,
    required CustomThemeSettings initial,
  }) {
    return showGeneralDialog<CustomThemeSettings>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) =>
          CustomThemeDialog(initial: initial),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CustomThemeDialog> createState() => _CustomThemeDialogState();
}

class _CustomThemeDialogState extends State<CustomThemeDialog> {
  late CustomThemeMode _mode;
  late Color _autoLight;
  late Color _manualLight;
  late Color _manualDark;
  late CustomThemeSurfaces _manualSurfacesLight;
  late CustomThemeSurfaces _manualSurfacesDark;
  late List<CustomThemeColorPair> _history;

  late TextEditingController _autoHexController;
  late TextEditingController _manualLightHexController;
  late TextEditingController _manualDarkHexController;
  late TextEditingController _surfaceLightBackgroundController;
  late TextEditingController _surfaceLightCardController;
  late TextEditingController _surfaceLightBorderController;
  late TextEditingController _surfaceDarkBackgroundController;
  late TextEditingController _surfaceDarkCardController;
  late TextEditingController _surfaceDarkBorderController;

  bool _suppressHexUpdate = false;
  bool _linkLightSurfaces = true;
  bool _linkDarkSurfaces = true;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.mode;
    _autoLight = widget.initial.autoLight;
    _manualLight = widget.initial.manualLight;
    _manualDark = widget.initial.manualDark;
    _manualSurfacesLight = widget.initial.manualSurfacesLight;
    _manualSurfacesDark = widget.initial.manualSurfacesDark;
    _history = List<CustomThemeColorPair>.from(widget.initial.history);
    _autoHexController = TextEditingController(text: _formatHex(_autoLight));
    _manualLightHexController = TextEditingController(
      text: _formatHex(_manualLight),
    );
    _manualDarkHexController = TextEditingController(
      text: _formatHex(_manualDark),
    );
    _surfaceLightBackgroundController = TextEditingController(
      text: _formatHex(_manualSurfacesLight.background),
    );
    _surfaceLightCardController = TextEditingController(
      text: _formatHex(_manualSurfacesLight.card),
    );
    _surfaceLightBorderController = TextEditingController(
      text: _formatHex(_manualSurfacesLight.border),
    );
    _surfaceDarkBackgroundController = TextEditingController(
      text: _formatHex(_manualSurfacesDark.background),
    );
    _surfaceDarkCardController = TextEditingController(
      text: _formatHex(_manualSurfacesDark.card),
    );
    _surfaceDarkBorderController = TextEditingController(
      text: _formatHex(_manualSurfacesDark.border),
    );
    _linkLightSurfaces = _manualSurfacesLight.matches(
      deriveThemeSurfaces(seed: _manualLight, brightness: Brightness.light),
    );
    _linkDarkSurfaces = _manualSurfacesDark.matches(
      deriveThemeSurfaces(seed: _manualDark, brightness: Brightness.dark),
    );
  }

  @override
  void dispose() {
    _autoHexController.dispose();
    _manualLightHexController.dispose();
    _manualDarkHexController.dispose();
    _surfaceLightBackgroundController.dispose();
    _surfaceLightCardController.dispose();
    _surfaceLightBorderController.dispose();
    _surfaceDarkBackgroundController.dispose();
    _surfaceDarkCardController.dispose();
    _surfaceDarkBorderController.dispose();
    super.dispose();
  }

  String _formatHex(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return value.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  Color? _parseHex(String raw) {
    if (raw.length != 6) return null;
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }

  void _syncHex(TextEditingController controller, Color color) {
    final next = _formatHex(color);
    if (controller.text.toUpperCase() == next) return;
    _suppressHexUpdate = true;
    controller.text = next;
    controller.selection = TextSelection.collapsed(offset: next.length);
    _suppressHexUpdate = false;
  }

  void _handleHexChanged(String value, ValueChanged<Color> onColorChanged) {
    if (_suppressHexUpdate) return;
    final color = _parseHex(value);
    if (color == null) return;
    onColorChanged(color);
  }

  void _updateAutoLight(Color color) {
    setState(() => _autoLight = color);
    _syncHex(_autoHexController, color);
  }

  void _updateManualLight(Color color) {
    setState(() => _manualLight = color);
    _syncHex(_manualLightHexController, color);
    if (_linkLightSurfaces) {
      _updateManualSurfacesLight(
        deriveThemeSurfaces(seed: color, brightness: Brightness.light),
      );
    }
  }

  void _updateManualDark(Color color) {
    setState(() => _manualDark = color);
    _syncHex(_manualDarkHexController, color);
    if (_linkDarkSurfaces) {
      _updateManualSurfacesDark(
        deriveThemeSurfaces(seed: color, brightness: Brightness.dark),
      );
    }
  }

  void _updateManualSurfacesLight(
    CustomThemeSurfaces surfaces, {
    bool linked = true,
  }) {
    setState(() {
      _manualSurfacesLight = surfaces;
      _linkLightSurfaces = linked;
    });
    _syncHex(_surfaceLightBackgroundController, surfaces.background);
    _syncHex(_surfaceLightCardController, surfaces.card);
    _syncHex(_surfaceLightBorderController, surfaces.border);
  }

  void _updateManualSurfacesDark(
    CustomThemeSurfaces surfaces, {
    bool linked = true,
  }) {
    setState(() {
      _manualSurfacesDark = surfaces;
      _linkDarkSurfaces = linked;
    });
    _syncHex(_surfaceDarkBackgroundController, surfaces.background);
    _syncHex(_surfaceDarkCardController, surfaces.card);
    _syncHex(_surfaceDarkBorderController, surfaces.border);
  }

  void _updateSurfaceColor({
    required bool isLight,
    required _SurfaceSlot slot,
    required Color color,
  }) {
    if (isLight) {
      final next = _manualSurfacesLight.copyWith(
        background: slot == _SurfaceSlot.background ? color : null,
        card: slot == _SurfaceSlot.card ? color : null,
        border: slot == _SurfaceSlot.border ? color : null,
      );
      _updateManualSurfacesLight(next, linked: false);
    } else {
      final next = _manualSurfacesDark.copyWith(
        background: slot == _SurfaceSlot.background ? color : null,
        card: slot == _SurfaceSlot.card ? color : null,
        border: slot == _SurfaceSlot.border ? color : null,
      );
      _updateManualSurfacesDark(next, linked: false);
    }
  }

  Future<void> _pickSurfaceColor({
    required String title,
    required bool isLight,
    required _SurfaceSlot slot,
    required Color color,
  }) async {
    final picked = await _SurfaceColorDialog.show(
      context: context,
      title: title,
      initial: color,
    );
    if (picked == null || !mounted) return;
    _updateSurfaceColor(isLight: isLight, slot: slot, color: picked);
  }

  void _applyHistory(CustomThemeColorPair pair) {
    if (_mode == CustomThemeMode.auto) {
      _updateAutoLight(pair.light);
      return;
    }
    _updateManualLight(pair.light);
    _updateManualDark(pair.dark);
  }

  void _save() {
    final pair = _mode == CustomThemeMode.manual
        ? CustomThemeColorPair(light: _manualLight, dark: _manualDark)
        : CustomThemeColorPair(
            light: _autoLight,
            dark: deriveAutoDarkColor(_autoLight),
          );
    final nextHistory = <CustomThemeColorPair>[pair, ..._history];
    if (nextHistory.length > 4) {
      nextHistory.removeRange(4, nextHistory.length);
    }
    final next = CustomThemeSettings(
      mode: _mode,
      autoLight: _autoLight,
      manualLight: _manualLight,
      manualDark: _manualDark,
      manualSurfacesLight: _manualSurfacesLight,
      manualSurfacesDark: _manualSurfacesDark,
      history: nextHistory,
    );
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? MemoFlowPalette.cardDark : Colors.white;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.55);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final field = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final accent = MemoFlowPalette.primary;
    final shadow = Colors.black.withValues(alpha: 0.16);
    final headerStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: textMain,
    );

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 26,
                    offset: const Offset(0, 18),
                    color: shadow,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.t.strings.settings.preferences.customTheme,
                      style: headerStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    _ModeToggle(
                      mode: _mode,
                      accent: accent,
                      field: field,
                      border: border,
                      textMuted: textMuted,
                      onSelect: (mode) => setState(() => _mode = mode),
                    ),
                    const SizedBox(height: 14),
                    if (_mode == CustomThemeMode.auto) ...[
                      _ColorSquarePicker(
                        color: _autoLight,
                        height: 180,
                        border: border,
                        onChanged: _updateAutoLight,
                      ),
                      const SizedBox(height: 10),
                      _HexInputRow(
                        controller: _autoHexController,
                        color: _autoLight,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) =>
                            _handleHexChanged(value, _updateAutoLight),
                      ),
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _HistoryRow(
                          title: context.t.strings.settings.preferences.history,
                          entries: _history,
                          border: border,
                          textMuted: textMuted,
                          onTap: _applyHistory,
                        ),
                      ],
                    ] else ...[
                      _ModeSectionHeader(
                        label: context.t.strings.settings.preferences.lightMode,
                        caption: 'LIGHT MODE',
                        textMain: textMain,
                        textMuted: textMuted,
                      ),
                      const SizedBox(height: 8),
                      _ColorSquarePicker(
                        color: _manualLight,
                        height: 150,
                        border: border,
                        onChanged: _updateManualLight,
                      ),
                      const SizedBox(height: 10),
                      _HexInputRow(
                        controller: _manualLightHexController,
                        color: _manualLight,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) =>
                            _handleHexChanged(value, _updateManualLight),
                      ),
                      const SizedBox(height: 12),
                      _SurfaceSectionHeader(
                        title: context.t.strings.settings.preferences.surfaces,
                        textMuted: textMuted,
                      ),
                      const SizedBox(height: 8),
                      _SurfaceColorRow(
                        label:
                            context.t.strings.settings.preferences.background,
                        controller: _surfaceLightBackgroundController,
                        color: _manualSurfacesLight.background,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) => _handleHexChanged(
                          value,
                          (color) => _updateSurfaceColor(
                            isLight: true,
                            slot: _SurfaceSlot.background,
                            color: color,
                          ),
                        ),
                        onPick: () => _pickSurfaceColor(
                          title: context
                              .t
                              .strings
                              .settings
                              .preferences
                              .backgroundColor,
                          isLight: true,
                          slot: _SurfaceSlot.background,
                          color: _manualSurfacesLight.background,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SurfaceColorRow(
                        label: context.t.strings.settings.preferences.card,
                        controller: _surfaceLightCardController,
                        color: _manualSurfacesLight.card,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) => _handleHexChanged(
                          value,
                          (color) => _updateSurfaceColor(
                            isLight: true,
                            slot: _SurfaceSlot.card,
                            color: color,
                          ),
                        ),
                        onPick: () => _pickSurfaceColor(
                          title:
                              context.t.strings.settings.preferences.cardColor,
                          isLight: true,
                          slot: _SurfaceSlot.card,
                          color: _manualSurfacesLight.card,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SurfaceColorRow(
                        label: context.t.strings.settings.preferences.border,
                        controller: _surfaceLightBorderController,
                        color: _manualSurfacesLight.border,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) => _handleHexChanged(
                          value,
                          (color) => _updateSurfaceColor(
                            isLight: true,
                            slot: _SurfaceSlot.border,
                            color: color,
                          ),
                        ),
                        onPick: () => _pickSurfaceColor(
                          title: context
                              .t
                              .strings
                              .settings
                              .preferences
                              .borderColor,
                          isLight: true,
                          slot: _SurfaceSlot.border,
                          color: _manualSurfacesLight.border,
                        ),
                      ),
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _HistoryRow(
                          title: context.t.strings.settings.preferences.history,
                          entries: _history,
                          border: border,
                          textMuted: textMuted,
                          onTap: _applyHistory,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _ModeSectionHeader(
                        label: context.t.strings.settings.preferences.darkMode,
                        caption: 'DARK MODE',
                        textMain: textMain,
                        textMuted: textMuted,
                      ),
                      const SizedBox(height: 8),
                      _ColorSquarePicker(
                        color: _manualDark,
                        height: 150,
                        border: border,
                        onChanged: _updateManualDark,
                      ),
                      const SizedBox(height: 10),
                      _HexInputRow(
                        controller: _manualDarkHexController,
                        color: _manualDark,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) =>
                            _handleHexChanged(value, _updateManualDark),
                      ),
                      const SizedBox(height: 12),
                      _SurfaceSectionHeader(
                        title: context.t.strings.settings.preferences.surfaces,
                        textMuted: textMuted,
                      ),
                      const SizedBox(height: 8),
                      _SurfaceColorRow(
                        label:
                            context.t.strings.settings.preferences.background,
                        controller: _surfaceDarkBackgroundController,
                        color: _manualSurfacesDark.background,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) => _handleHexChanged(
                          value,
                          (color) => _updateSurfaceColor(
                            isLight: false,
                            slot: _SurfaceSlot.background,
                            color: color,
                          ),
                        ),
                        onPick: () => _pickSurfaceColor(
                          title: context
                              .t
                              .strings
                              .settings
                              .preferences
                              .backgroundColor,
                          isLight: false,
                          slot: _SurfaceSlot.background,
                          color: _manualSurfacesDark.background,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SurfaceColorRow(
                        label: context.t.strings.settings.preferences.card,
                        controller: _surfaceDarkCardController,
                        color: _manualSurfacesDark.card,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) => _handleHexChanged(
                          value,
                          (color) => _updateSurfaceColor(
                            isLight: false,
                            slot: _SurfaceSlot.card,
                            color: color,
                          ),
                        ),
                        onPick: () => _pickSurfaceColor(
                          title:
                              context.t.strings.settings.preferences.cardColor,
                          isLight: false,
                          slot: _SurfaceSlot.card,
                          color: _manualSurfacesDark.card,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SurfaceColorRow(
                        label: context.t.strings.settings.preferences.border,
                        controller: _surfaceDarkBorderController,
                        color: _manualSurfacesDark.border,
                        field: field,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (value) => _handleHexChanged(
                          value,
                          (color) => _updateSurfaceColor(
                            isLight: false,
                            slot: _SurfaceSlot.border,
                            color: color,
                          ),
                        ),
                        onPick: () => _pickSurfaceColor(
                          title: context
                              .t
                              .strings
                              .settings
                              .preferences
                              .borderColor,
                          isLight: false,
                          slot: _SurfaceSlot.border,
                          color: _manualSurfacesDark.border,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accent,
                              side: BorderSide(
                                color: accent.withValues(alpha: 0.7),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(context.t.strings.common.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: Text(
                              _mode == CustomThemeMode.manual
                                  ? context.t.strings.common.saveSettings
                                  : context.t.strings.common.save,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.accent,
    required this.field,
    required this.border,
    required this.textMuted,
    required this.onSelect,
  });

  final CustomThemeMode mode;
  final Color accent;
  final Color field;
  final Color border;
  final Color textMuted;
  final ValueChanged<CustomThemeMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: field,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _ModeToggleButton(
            label: context.t.strings.common.auto,
            selected: mode == CustomThemeMode.auto,
            accent: accent,
            textMuted: textMuted,
            onTap: () => onSelect(CustomThemeMode.auto),
          ),
          _ModeToggleButton(
            label: context.t.strings.common.manual,
            selected: mode == CustomThemeMode.manual,
            accent: accent,
            textMuted: textMuted,
            onTap: () => onSelect(CustomThemeMode.manual),
          ),
        ],
      ),
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  const _ModeToggleButton({
    required this.label,
    required this.selected,
    required this.accent,
    required this.textMuted,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = selected
        ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white)
        : Colors.transparent;
    final shadow = isDark
        ? Colors.black.withValues(alpha: 0.32)
        : Colors.black.withValues(alpha: 0.08);
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                    color: shadow,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? accent : textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSquarePicker extends StatelessWidget {
  const _ColorSquarePicker({
    required this.color,
    required this.height,
    required this.border,
    required this.onChanged,
  });

  final Color color;
  final double height;
  final Color border;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(color);
    return Column(
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _HslPalette(color: color, onChanged: onChanged),
          ),
        ),
        const SizedBox(height: 8),
        _HueSlider(
          hsv: hsv,
          border: border,
          onChanged: (next) => onChanged(next.toColor()),
        ),
      ],
    );
  }
}

class _HslPalette extends StatelessWidget {
  const _HslPalette({required this.color, required this.onChanged});

  final Color color;
  final ValueChanged<Color> onChanged;

  void _handleOffset(Offset localPosition, Size size, HSLColor hsl) {
    if (size.width <= 0 || size.height <= 0) return;
    final dx = localPosition.dx.clamp(0.0, size.width);
    final dy = localPosition.dy.clamp(0.0, size.height);
    final saturation = (dx / size.width).clamp(0.0, 1.0);
    final lightness = (1 - dy / size.height).clamp(0.0, 1.0);
    onChanged(
      hsl.withSaturation(saturation).withLightness(lightness).toColor(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;
        final size = Size(width, height);
        return GestureDetector(
          onPanDown: (details) =>
              _handleOffset(details.localPosition, size, hsl),
          onPanUpdate: (details) =>
              _handleOffset(details.localPosition, size, hsl),
          child: CustomPaint(size: size, painter: _HslPalettePainter(hsl)),
        );
      },
    );
  }
}

class _HslPalettePainter extends CustomPainter {
  _HslPalettePainter(this.hsl);

  final HSLColor hsl;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;
    final gradientH = LinearGradient(
      colors: [
        const Color(0xff808080),
        HSLColor.fromAHSL(1.0, hsl.hue, 1.0, 0.5).toColor(),
      ],
    );
    const gradientV = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.0, 0.5, 0.5, 1],
      colors: [
        Colors.white,
        Color(0x00ffffff),
        Colors.transparent,
        Colors.black,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradientH.createShader(rect));
    canvas.drawRect(rect, Paint()..shader = gradientV.createShader(rect));

    final pointer = Offset(
      size.width * hsl.saturation,
      size.height * (1 - hsl.lightness),
    );
    final pointerColor = useWhiteForeground(hsl.toColor())
        ? Colors.white
        : Colors.black;
    canvas.drawCircle(
      pointer,
      size.height * 0.04,
      Paint()
        ..color = pointerColor
        ..strokeWidth = 1.5
        ..blendMode = BlendMode.luminosity
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _HslPalettePainter oldDelegate) {
    return oldDelegate.hsl != hsl;
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({
    required this.hsv,
    required this.border,
    required this.onChanged,
  });

  final HSVColor hsv;
  final Color border;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: ColorPickerSlider(
          TrackType.hue,
          hsv,
          onChanged,
          displayThumbColor: true,
          fullThumbColor: true,
        ),
      ),
    );
  }
}

class _HexInputRow extends StatelessWidget {
  const _HexInputRow({
    required this.controller,
    required this.color,
    required this.field,
    required this.border,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
    this.onColorTap,
  });

  final TextEditingController controller;
  final Color color;
  final Color field;
  final Color border;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<String> onChanged;
  final VoidCallback? onColorTap;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
    );
    final dotWidget = onColorTap == null
        ? dot
        : InkWell(
            onTap: onColorTap,
            customBorder: const CircleBorder(),
            child: dot,
          );

    String formatHex(Color color) {
      final value = color.toARGB32() & 0x00FFFFFF;
      return value.toRadixString(16).padLeft(6, '0').toUpperCase();
    }

    Future<void> handleCopy() async {
      final text = '#${formatHex(color)}';
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      showTopToast(context, context.t.strings.common.copiedToClipboard);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          dotWidget,
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              inputFormatters: [
                UpperCaseTextFormatter(),
                FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                prefixText: '#',
                prefixStyle: TextStyle(
                  color: textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextStyle(
                color: textMain,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: handleCopy,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 16, color: textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SurfaceSlot { background, card, border }

class _SurfaceSectionHeader extends StatelessWidget {
  const _SurfaceSectionHeader({required this.title, required this.textMuted});

  final String title;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: textMuted,
      ),
    );
  }
}

class _SurfaceColorRow extends StatelessWidget {
  const _SurfaceColorRow({
    required this.label,
    required this.controller,
    required this.color,
    required this.field,
    required this.border,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
    required this.onPick,
  });

  final String label;
  final TextEditingController controller;
  final Color color;
  final Color field;
  final Color border;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<String> onChanged;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
          ),
        ),
        SizedBox(
          width: 150,
          child: _HexInputRow(
            controller: controller,
            color: color,
            field: field,
            border: border,
            textMain: textMain,
            textMuted: textMuted,
            onChanged: onChanged,
            onColorTap: onPick,
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.title,
    required this.entries,
    required this.border,
    required this.textMuted,
    required this.onTap,
  });

  final String title;
  final List<CustomThemeColorPair> entries;
  final Color border;
  final Color textMuted;
  final ValueChanged<CustomThemeColorPair> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              _HistoryDot(
                pair: entry,
                border: border,
                onTap: () => onTap(entry),
              ),
          ],
        ),
      ],
    );
  }
}

class _HistoryDot extends StatelessWidget {
  const _HistoryDot({
    required this.pair,
    required this.border,
    required this.onTap,
  });

  final CustomThemeColorPair pair;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [pair.light, pair.dark]),
          border: Border.all(color: border),
        ),
      ),
    );
  }
}

class _ModeSectionHeader extends StatelessWidget {
  const _ModeSectionHeader({
    required this.label,
    required this.caption,
    required this.textMain,
    required this.textMuted,
  });

  final String label;
  final String caption;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
        ),
        const Spacer(),
        Text(
          caption,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: textMuted,
          ),
        ),
      ],
    );
  }
}

class _SurfaceColorDialog extends StatefulWidget {
  const _SurfaceColorDialog({required this.title, required this.initial});

  final String title;
  final Color initial;

  static Future<Color?> show({
    required BuildContext context,
    required String title,
    required Color initial,
  }) {
    return showDialog<Color>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _SurfaceColorDialog(title: title, initial: initial),
    );
  }

  @override
  State<_SurfaceColorDialog> createState() => _SurfaceColorDialogState();
}

class _SurfaceColorDialogState extends State<_SurfaceColorDialog> {
  late Color _color;
  late TextEditingController _hexController;
  bool _suppressHexUpdate = false;

  @override
  void initState() {
    super.initState();
    _color = widget.initial;
    _hexController = TextEditingController(text: _formatHex(_color));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _formatHex(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return value.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  Color? _parseHex(String raw) {
    if (raw.length != 6) return null;
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }

  void _syncHex(Color color) {
    final next = _formatHex(color);
    if (_hexController.text.toUpperCase() == next) return;
    _suppressHexUpdate = true;
    _hexController.text = next;
    _hexController.selection = TextSelection.collapsed(offset: next.length);
    _suppressHexUpdate = false;
  }

  void _updateColor(Color color) {
    setState(() => _color = color);
    _syncHex(color);
  }

  void _handleHexChanged(String value) {
    if (_suppressHexUpdate) return;
    final color = _parseHex(value);
    if (color == null) return;
    _updateColor(color);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? MemoFlowPalette.cardDark : Colors.white;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.55);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final field = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final accent = MemoFlowPalette.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: TextStyle(fontWeight: FontWeight.w800, color: textMain),
            ),
            const SizedBox(height: 12),
            _ColorSquarePicker(
              color: _color,
              height: 140,
              border: border,
              onChanged: _updateColor,
            ),
            const SizedBox(height: 10),
            _HexInputRow(
              controller: _hexController,
              color: _color,
              field: field,
              border: border,
              textMain: textMain,
              textMuted: textMuted,
              onChanged: _handleHexChanged,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withValues(alpha: 0.7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(context.t.strings.common.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_color),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: Text(context.t.strings.common.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
