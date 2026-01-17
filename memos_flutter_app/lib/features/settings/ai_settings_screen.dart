import 'package:flutter/material.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import 'ai_provider_settings_screen.dart';
import 'ai_user_profile_screen.dart';

class AiSettingsScreen extends StatelessWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

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
        title: Text(context.tr(zh: 'AI 设置', en: 'AI Settings')),
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
              _CardRow(
                card: card,
                title: context.tr(zh: 'AI 提供方', en: 'AI Provider'),
                subtitle: context.tr(zh: '帮助 AI 更了解你', en: 'Help AI understand you better'),
                textMain: textMain,
                textMuted: textMuted,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AiProviderSettingsScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _CardRow(
                card: card,
                title: context.tr(zh: '我的资料', en: 'My Profile'),
                subtitle: '',
                textMain: textMain,
                textMuted: textMuted,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AiUserProfileScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.title,
    required this.subtitle,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final Color card;
  final String title;
  final String subtitle;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: textMain)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: textMuted)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
