import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../state/preferences_provider.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends ConsumerState<LanguageSelectionScreen> {
  late AppLanguage _selected;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(appPreferencesProvider).language;
  }

  void _confirmSelection() {
    final notifier = ref.read(appPreferencesProvider.notifier);
    notifier.setAll(
      AppPreferences.defaultsForLanguage(_selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    String tr({required String zh, required String en}) =>
        trByLanguage(language: _selected, zh: zh, en: en);

    return Scaffold(
      backgroundColor: bg,
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(zh: '\u9009\u62E9\u8BED\u8A00', en: 'Select language'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      zh: '\u9009\u62E9 MemoFlow \u7684\u663E\u793A\u8BED\u8A00.',
                      en: 'Choose your preferred language for MemoFlow.',
                    ),
                    style: TextStyle(fontSize: 13, color: textMuted),
                  ),
                  const SizedBox(height: 24),
                  _LanguageCard(
                    language: AppLanguage.zhHans,
                    selected: _selected == AppLanguage.zhHans,
                    background: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => setState(() => _selected = AppLanguage.zhHans),
                  ),
                  const SizedBox(height: 12),
                  _LanguageCard(
                    language: AppLanguage.en,
                    selected: _selected == AppLanguage.en,
                    background: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => setState(() => _selected = AppLanguage.en),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _confirmSelection,
                      style: FilledButton.styleFrom(
                        backgroundColor: MemoFlowPalette.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Text(
                        tr(zh: '\u7EE7\u7EED', en: 'Continue'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.language,
    required this.selected,
    required this.background,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final Color background;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = selected ? MemoFlowPalette.primary : (isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight);
    final fill = selected ? MemoFlowPalette.primary.withValues(alpha: isDark ? 0.22 : 0.1) : background;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.labelEn,
                      style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      language.labelZh,
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? MemoFlowPalette.primary : textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
