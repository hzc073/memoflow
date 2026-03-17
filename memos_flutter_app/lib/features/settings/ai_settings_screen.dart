import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/ai_settings_provider.dart';
import 'ai_provider_logo.dart';
import 'ai_proxy_settings_screen.dart';
import 'ai_service_detail_screen.dart';
import 'ai_service_model_screen.dart';
import 'ai_service_wizard_screen.dart';
import 'ai_user_profile_screen.dart';

class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final useDesktopAddAction =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    void openAddService() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AiServiceWizardScreen()),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: showBackButton,
        leading: showBackButton
            ? IconButton(
                tooltip: context.t.strings.legacy.msg_back,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Text(context.t.strings.legacy.msg_ai_settings),
        actions: [
          if (useDesktopAddAction)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: openAddService,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  isZh ? '\u6dfb\u52a0\u670d\u52a1' : 'Add Service',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
        ],
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
              _CardRow(
                card: card,
                title: context.t.strings.legacy.msg_my_profile,
                subtitle: '',
                textMain: textMain,
                textMuted: textMuted,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AiUserProfileScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _CardRow(
                card: card,
                title: context.t.strings.aiProxy.title,
                subtitle: _proxySummary(context, settings.proxySettings),
                textMain: textMain,
                textMuted: textMuted,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AiProxySettingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                isZh ? '\u670d\u52a1\u5217\u8868' : 'Services',
                style: TextStyle(fontWeight: FontWeight.w800, color: textMain),
              ),
              const SizedBox(height: 12),
              if (settings.services.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isZh
                            ? '\u8fd8\u6ca1\u6709 AI \u670d\u52a1\uff0c\u70b9\u51fb\u300c\u6dfb\u52a0\u670d\u52a1\u300d\u5f00\u59cb\u914d\u7f6e\u3002'
                            : 'No AI services yet. Tap Add Service to get started.',
                        style: TextStyle(color: textMuted, height: 1.5),
                      ),
                    ],
                  ),
                )
              else
                ...settings.services.map(
                  (service) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ServiceCard(service: service),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: useDesktopAddAction
          ? null
          : FloatingActionButton.extended(
              onPressed: openAddService,
              icon: const Icon(Icons.add_rounded),
              label: Text(isZh ? '\u6dfb\u52a0\u670d\u52a1' : 'Add Service'),
            ),
    );
  }
}

class _ServiceCard extends ConsumerWidget {
  const _ServiceCard({required this.service});

  final AiServiceInstance service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(aiSettingsProvider);
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final template = findAiProviderTemplate(service.templateId);
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.62);
    final defaultModelIds = _defaultModelIds(settings);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AiServiceDetailScreen(serviceId: service.serviceId),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AiProviderLogo(template: template, size: 44, iconSize: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          template == null
                              ? service.templateId
                              : localizedAiProviderTemplateDisplayName(
                                  template,
                                  isZh: isZh,
                                ),
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: service.enabled,
                    onChanged: (value) {
                      ref
                          .read(aiSettingsProvider.notifier)
                          .setServiceEnabled(service.serviceId, value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...service.models.map(
                    (model) => _ServiceBadge(
                      label: model.modelKey,
                      leadingCheck: defaultModelIds.contains(model.modelId),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                service.baseUrl.trim().isEmpty
                    ? (isZh
                          ? '\u672a\u8bbe\u7f6e Base URL'
                          : 'Base URL not configured')
                    : service.baseUrl,
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _addModel(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      isZh ? '\u6dfb\u52a0\u6a21\u578b' : 'Add Model',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AiServiceDetailScreen(
                            serviceId: service.serviceId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(
                      isZh ? '\u7ba1\u7406\u670d\u52a1' : 'Manage Service',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addModel(BuildContext context, WidgetRef ref) async {
    final result = await showAiModelEditorDialog(context, service: service);
    if (result == null) return;
    await ref
        .read(aiSettingsProvider.notifier)
        .upsertServiceModel(service.serviceId, result);
    if (!context.mounted) return;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    showTopToast(
      context,
      isZh ? '\u6a21\u578b\u5df2\u6dfb\u52a0\u3002' : 'Model added.',
    );
  }

  Set<String> _defaultModelIds(AiSettings settings) {
    final result = <String>{};
    for (final binding in settings.taskRouteBindings) {
      if (binding.serviceId != service.serviceId) continue;
      result.add(binding.modelId);
    }
    _markSelectedProfileModel(
      result,
      modelKey: settings.selectedGenerationProfile.model,
      baseUrl: settings.selectedGenerationProfile.baseUrl,
      apiKey: settings.selectedGenerationProfile.apiKey,
    );
    final embeddingProfile = settings.selectedEmbeddingProfile;
    if (embeddingProfile != null) {
      _markSelectedProfileModel(
        result,
        modelKey: embeddingProfile.model,
        baseUrl: embeddingProfile.baseUrl,
        apiKey: embeddingProfile.apiKey,
      );
    }
    return result;
  }

  void _markSelectedProfileModel(
    Set<String> result, {
    required String modelKey,
    required String baseUrl,
    required String apiKey,
  }) {
    final normalizedModelKey = modelKey.trim().toLowerCase();
    final normalizedBaseUrl = baseUrl.trim().toLowerCase();
    final normalizedApiKey = apiKey.trim();
    if (normalizedModelKey.isEmpty) return;
    for (final model in service.models) {
      if (model.modelKey.trim().toLowerCase() != normalizedModelKey) continue;
      if (normalizedBaseUrl.isNotEmpty &&
          service.baseUrl.trim().toLowerCase() != normalizedBaseUrl) {
        continue;
      }
      if (normalizedApiKey.isNotEmpty &&
          service.apiKey.trim() != normalizedApiKey) {
        continue;
      }
      result.add(model.modelId);
    }
  }
}

class _ServiceBadge extends StatelessWidget {
  const _ServiceBadge({required this.label, this.leadingCheck = false});

  final String label;
  final bool leadingCheck;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingCheck) ...[
            Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: Colors.green.shade600,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
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
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

String _proxySummary(BuildContext context, AiProxySettings settings) {
  final t = context.t.strings.aiProxy;
  if (!settings.isConfigured) return t.notConfigured;
  return switch (settings.protocol) {
    AiProxyProtocol.http => t.statusHttp(
      host: settings.host,
      port: settings.port,
    ),
    AiProxyProtocol.socks5 => t.statusSocks5(
      host: settings.host,
      port: settings.port,
    ),
  };
}
