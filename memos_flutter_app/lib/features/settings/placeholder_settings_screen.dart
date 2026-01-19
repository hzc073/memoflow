import 'package:flutter/material.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';

class SettingsPlaceholderScreen extends StatelessWidget {
  const SettingsPlaceholderScreen({
    super.key,
    required this.titleZh,
    required this.titleEn,
    required this.messageZh,
    required this.messageEn,
  });

  final String titleZh;
  final String titleEn;
  final String messageZh;
  final String messageEn;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    final title = context.tr(zh: titleZh, en: titleEn);
    final message = context.tr(zh: messageZh, en: messageEn);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.tr(zh: 'Back', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title),
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
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_empty, size: 36, color: textMuted),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
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
