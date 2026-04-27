import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../core/windows_adaptive_surface.dart';
import '../../data/ai/ai_route_config.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../state/settings/ai_settings_provider.dart';

class AiRouteSettingsScreen extends ConsumerWidget {
  const AiRouteSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generationTileKey = GlobalKey();
    final embeddingTileKey = GlobalKey();
    final settings = ref.watch(aiSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.62);
    final generation = AiRouteResolver.resolveTaskRoute(
      services: settings.services,
      bindings: settings.taskRouteBindings,
      routeId: AiTaskRouteId.summary,
      capability: AiCapability.chat,
    );
    final embedding = AiRouteResolver.resolveTaskRoute(
      services: settings.services,
      bindings: settings.taskRouteBindings,
      routeId: AiTaskRouteId.embeddingRetrieval,
      capability: AiCapability.embedding,
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(isZh ? '默认用途' : 'Default Routes'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _RouteTile(
            key: generationTileKey,
            title: isZh ? '生成默认' : 'Generation Default',
            subtitle: generation == null
                ? (isZh ? '未绑定模型' : 'No model selected')
                : '${generation.service.displayName} · ${generation.model.displayName}',
            card: card,
            textMain: textMain,
            textMuted: textMuted,
            onTap: () => _pickRoute(
              context,
              ref,
              anchorContext: generationTileKey.currentContext,
              routeIds: const <AiTaskRouteId>[
                AiTaskRouteId.summary,
                AiTaskRouteId.analysisReport,
                AiTaskRouteId.quickPrompt,
              ],
              capability: AiCapability.chat,
            ),
          ),
          const SizedBox(height: 12),
          _RouteTile(
            key: embeddingTileKey,
            title: 'Embedding Default',
            subtitle: embedding == null
                ? (isZh ? '未绑定模型' : 'No model selected')
                : '${embedding.service.displayName} · ${embedding.model.displayName}',
            card: card,
            textMain: textMain,
            textMuted: textMuted,
            onTap: () => _pickRoute(
              context,
              ref,
              anchorContext: embeddingTileKey.currentContext,
              routeIds: const <AiTaskRouteId>[AiTaskRouteId.embeddingRetrieval],
              capability: AiCapability.embedding,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRoute(
    BuildContext context,
    WidgetRef ref, {
    BuildContext? anchorContext,
    required List<AiTaskRouteId> routeIds,
    required AiCapability capability,
  }) async {
    final settings = ref.read(aiSettingsProvider);
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final options = selectableRouteOptionsForCapability(
      settings,
      capability: capability,
    );
    if (options.isEmpty) {
      showTopToast(
        context,
        isZh ? '请先添加可用模型。' : 'Add a compatible model first.',
      );
      return;
    }

    Widget buildRoutePicker(BuildContext surfaceContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                isZh ? '选择默认模型' : 'Choose Default Model',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                title: Text(option.model.displayName),
                subtitle: Text(option.service.displayName),
                onTap: () => Navigator.of(surfaceContext).pop(option),
              ),
          ],
        ),
      );
    }

    final selected = await _showRoutePickerSurface(
      context,
      buildRoutePicker,
      anchorContext: anchorContext,
    );
    if (selected == null) return;

    final replacements = routeIds
        .map(
          (routeId) => AiTaskRouteBinding(
            routeId: routeId,
            serviceId: selected.service.serviceId,
            modelId: selected.model.modelId,
            capability: capability,
          ),
        )
        .toList(growable: false);
    final current =
        settings.taskRouteBindings
            .where((binding) => !routeIds.contains(binding.routeId))
            .toList(growable: true)
          ..addAll(replacements);
    await ref
        .read(aiSettingsProvider.notifier)
        .replaceTaskRouteBindings(current);
    if (!context.mounted) return;
    showTopToast(context, isZh ? '默认用途已更新。' : 'Default routes updated.');
  }

  Future<AiSelectableRouteOption?> _showRoutePickerSurface(
    BuildContext context,
    WidgetBuilder builder, {
    BuildContext? anchorContext,
  }) {
    if (shouldUseWindowsAdaptiveSurface(context)) {
      return showWindowsAdaptiveSurface<AiSelectableRouteOption>(
        context: context,
        kind: WindowsAdaptiveSurfaceKind.popover,
        anchorContext: anchorContext,
        fallbackAlignment: Alignment.topLeft,
        maxWidth: 480,
        builder: builder,
      );
    }
    return showModalBottomSheet<AiSelectableRouteOption>(
      context: context,
      showDragHandle: true,
      builder: builder,
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color card;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
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
