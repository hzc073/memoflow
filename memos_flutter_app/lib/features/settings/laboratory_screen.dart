import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import 'customize_drawer_screen.dart';
import 'shortcuts_settings_screen.dart';
import 'webhooks_settings_screen.dart';
import '../../i18n/strings.g.dart';

class LaboratoryScreen extends ConsumerWidget {
  const LaboratoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final sessionState = ref.watch(appSessionProvider).valueOrNull;
    final currentAccount = sessionState?.currentAccount;
    final effectiveUseLegacyApi = currentAccount == null
        ? prefs.useLegacyApi
        : ref
              .read(appSessionProvider.notifier)
              .resolveUseLegacyApiForAccount(
                account: currentAccount,
                globalDefault: prefs.useLegacyApi,
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
        title: Text(context.t.strings.legacy.msg_laboratory),
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
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      _ToggleCard(
                        card: card,
                        label: context
                            .t
                            .strings
                            .legacy
                            .msg_legacy_api_compatibility,
                        description: context
                            .t
                            .strings
                            .legacy
                            .msg_use_legacy_endpoints_older_memos_servers,
                        value: effectiveUseLegacyApi,
                        textMain: textMain,
                        textMuted: textMuted,
                        onChanged: (v) async {
                          if (currentAccount != null) {
                            await ref
                                .read(appSessionProvider.notifier)
                                .setCurrentAccountUseLegacyApiOverride(v);
                            return;
                          }
                          ref
                              .read(appPreferencesProvider.notifier)
                              .setUseLegacyApi(v);
                        },
                      ),
                      const SizedBox(height: 12),
                      _CardRow(
                        card: card,
                        label: context.t.strings.legacy.msg_customize_sidebar,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CustomizeDrawerScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CardRow(
                        card: card,
                        label: context.t.strings.legacy.msg_shortcuts,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ShortcutsSettingsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CardRow(
                        card: card,
                        label: context.t.strings.legacy.msg_webhooks,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WebhooksSettingsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    children: [
                      Text(
                        'MemoFlow',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: MemoFlowPalette.primary.withValues(
                            alpha: isDark ? 0.85 : 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'VERSION 1.0.13',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: MemoFlowPalette.primary.withValues(
                            alpha: isDark ? 0.55 : 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.card,
    required this.label,
    required this.description,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
  });

  final Color card;
  final String label;
  final String description;
  final bool value;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
            if (description.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 44),
                child: Text(
                  description,
                  style: TextStyle(fontSize: 12, color: textMuted, height: 1.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.label,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final Color card;
  final String label;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
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
