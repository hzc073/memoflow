import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/top_toast.dart';
import '../../data/ai/ai_route_config.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../state/settings/ai_settings_provider.dart';
import 'settings_ui.dart';

class AiRouteSettingsScreen extends ConsumerWidget {
  const AiRouteSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiSettingsProvider);
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
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

    return SettingsPage(
      title: Text(isZh ? '默认用途' : 'Default Routes'),
      children: [
        SettingsSection(
          children: [
            SettingsValueRow(
              label: isZh ? '生成默认' : 'Generation Default',
              value: generation == null
                  ? (isZh ? '未绑定模型' : 'No model selected')
                  : '${generation.service.displayName} · ${generation.model.displayName}',
              onTap: () => _pickRoute(
                context,
                ref,
                routeIds: const <AiTaskRouteId>[
                  AiTaskRouteId.summary,
                  AiTaskRouteId.analysisReport,
                  AiTaskRouteId.quickPrompt,
                ],
                capability: AiCapability.chat,
              ),
            ),
            SettingsValueRow(
              label: 'Embedding Default',
              value: embedding == null
                  ? (isZh ? '未绑定模型' : 'No model selected')
                  : '${embedding.service.displayName} · ${embedding.model.displayName}',
              onTap: () => _pickRoute(
                context,
                ref,
                routeIds: const <AiTaskRouteId>[
                  AiTaskRouteId.embeddingRetrieval,
                ],
                capability: AiCapability.embedding,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickRoute(
    BuildContext context,
    WidgetRef ref, {
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

    final selected =
        await showSettingsSingleChoicePicker<AiSelectableRouteOption>(
          context: context,
          title: isZh ? '选择默认模型' : 'Choose Default Model',
          value: null,
          options: [
            for (final option in options)
              SettingsChoiceOption<AiSelectableRouteOption>(
                value: option,
                label: option.model.displayName,
                description: option.service.displayName,
              ),
          ],
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
}
