import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/models/home_navigation_preferences.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import 'bottom_navigation_mode_settings_screen.dart';

class NavigationModeScreen extends ConsumerWidget {
  const NavigationModeScreen({super.key});

  static const classicOptionKey = ValueKey<String>(
    'navigation-mode-classic-option',
  );
  static const bottomSelectKey = ValueKey<String>(
    'navigation-mode-bottom-select',
  );
  static const bottomSettingsKey = ValueKey<String>(
    'navigation-mode-bottom-settings',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationPrefs = ref.watch(
      currentWorkspacePreferencesProvider.select(
        (prefs) => prefs.homeNavigationPreferences,
      ),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.7 : 0.65);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final bottomBarSelected =
        navigationPrefs.mode == HomeNavigationMode.bottomBar;

    void selectMode(HomeNavigationMode mode) {
      if (mode == navigationPrefs.mode) return;
      ref
          .read(currentWorkspacePreferencesProvider.notifier)
          .setHomeNavigationMode(mode);
    }

    Future<void> openBottomSettings() async {
      if (!bottomBarSelected) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const BottomNavigationModeSettingsScreen(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.t.strings.legacy.msg_back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.t.strings.legacy.msg_navigation_mode),
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
              _SectionCard(
                card: card,
                divider: divider,
                children: [
                  _ModeOptionRow(
                    key: classicOptionKey,
                    label: context.t.strings.legacy.msg_navigation_mode_classic,
                    selected:
                        navigationPrefs.mode == HomeNavigationMode.classic,
                    textColor: textMain,
                    onTap: () => selectMode(HomeNavigationMode.classic),
                  ),
                  _BottomModeSplitRow(
                    selectKey: bottomSelectKey,
                    settingsKey: bottomSettingsKey,
                    label:
                        context.t.strings.legacy.msg_navigation_mode_bottom_bar,
                    selected: bottomBarSelected,
                    textColor: textMain,
                    dividerColor: divider,
                    onSelect: () => selectMode(HomeNavigationMode.bottomBar),
                    onOpenSettings: bottomBarSelected
                        ? openBottomSettings
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      context.tr(
                        zh: '\u6B64\u8BBE\u7F6E\u4F1A\u5F71\u54CD\u9996\u9875\u5BFC\u822A\u6837\u5F0F\uFF1B\u8FD4\u56DE\u9996\u9875\u540E\u53EF\u770B\u5230\u5B9E\u9645\u6548\u679C\u3002',
                        en: 'This changes the Home screen navigation style; go back to Home to preview it.',
                      ),
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
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

class _ModeOptionRow extends StatelessWidget {
  const _ModeOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<bool>(
      groupValue: selected,
      onChanged: (value) {
        if (value == true) onTap();
      },
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Radio<bool>(value: true, activeColor: MemoFlowPalette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: textColor, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomModeSplitRow extends StatelessWidget {
  const _BottomModeSplitRow({
    required this.selectKey,
    required this.settingsKey,
    required this.label,
    required this.selected,
    required this.textColor,
    required this.dividerColor,
    required this.onSelect,
    required this.onOpenSettings,
  });

  final Key selectKey;
  final Key settingsKey;
  final String label;
  final bool selected;
  final Color textColor;
  final Color dividerColor;
  final VoidCallback onSelect;
  final Future<void> Function()? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final settingsEnabled = onOpenSettings != null;

    return SizedBox(
      height: 76,
      child: Row(
        children: [
          Expanded(
            flex: 8,
            child: RadioGroup<bool>(
              groupValue: selected,
              onChanged: (value) {
                if (value == true) onSelect();
              },
              child: InkWell(
                key: selectKey,
                onTap: onSelect,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        activeColor: MemoFlowPalette.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: VerticalDivider(width: 1, thickness: 1, color: dividerColor),
          ),
          Expanded(
            flex: 2,
            child: Opacity(
              opacity: settingsEnabled ? 1 : 0.35,
              child: InkWell(
                key: settingsKey,
                onTap: settingsEnabled ? () => onOpenSettings!() : null,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: textColor.withValues(alpha: 0.72),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        color: textColor.withValues(alpha: 0.52),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(height: 1, thickness: 1, color: divider),
          ],
        ],
      ),
    );
  }
}
