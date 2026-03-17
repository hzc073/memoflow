import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../data/ai/ai_settings_log.dart';
import '../../data/logs/log_manager.dart';
import '../../core/top_toast.dart';
import '../../core/uid.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../state/settings/ai_settings_provider.dart';

Future<AiModelEntry?> showAiModelEditorDialog(
  BuildContext context, {
  required AiServiceInstance service,
  AiModelEntry? initial,
}) {
  return showDialog<AiModelEntry>(
    context: context,
    builder: (_) => _AiModelEditorDialog(service: service, initial: initial),
  );
}

class AiServiceModelScreen extends ConsumerWidget {
  const AiServiceModelScreen({
    super.key,
    required this.serviceId,
    this.embedded = false,
  });

  final String serviceId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiSettingsProvider);
    final service = settings.services.firstById(serviceId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;

    if (service == null) {
      final missing = Center(
        child: Text(isZh ? '服务不存在。' : 'Service not found.'),
      );
      if (embedded) return missing;
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(isZh ? '模型管理' : 'Models'),
        ),
        body: missing,
      );
    }

    final content = _AiServiceModelPanel(service: service, embedded: embedded);
    if (embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(isZh ? '模型管理' : 'Models'),
      ),
      body: content,
    );
  }
}

class _AiServiceModelPanel extends ConsumerStatefulWidget {
  const _AiServiceModelPanel({required this.service, required this.embedded});

  final AiServiceInstance service;
  final bool embedded;

  @override
  ConsumerState<_AiServiceModelPanel> createState() =>
      _AiServiceModelPanelState();
}

enum _ModelSourceFilter { all, manual, discovered, migrated, disabled }

enum _ModelSortMode { nameAsc, nameDesc, sourceThenName }

class _AiServiceModelPanelState extends ConsumerState<_AiServiceModelPanel> {
  late final TextEditingController _searchController;
  _ModelSourceFilter _sourceFilter = _ModelSourceFilter.all;
  _ModelSortMode _sortMode = _ModelSortMode.nameAsc;
  bool _isSyncingModels = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiSettingsProvider);
    final service =
        settings.services.firstById(widget.service.serviceId) ?? widget.service;
    final template = findAiProviderTemplate(service.templateId);
    final presets = template == null
        ? const <AiBuiltinModelPreset>[]
        : builtinModelPresetsForTemplate(template);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.62);
    final query = _searchController.text.trim().toLowerCase();
    final filteredModels = _buildVisibleModels(service.models, query);
    final hasModelFilters =
        query.isNotEmpty || _sourceFilter != _ModelSourceFilter.all;

    return ListView(
      shrinkWrap: widget.embedded,
      physics: widget.embedded
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: widget.embedded
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isZh ? '模型列表' : 'Model Library',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CountPill(count: filteredModels.length),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: isZh
                            ? '搜索模型名或 Key'
                            : 'Search model name or key',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () =>
                        _openEditor(context, ref, service: service),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(isZh ? '添加模型' : 'Add Model'),
                  ),
                  if (template?.supportsModelDiscovery ?? false) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _isSyncingModels
                          ? null
                          : () => _syncModels(service),
                      icon: _isSyncingModels
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(isZh ? '同步模型' : 'Sync Models'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PopupMenuButton<_ModelSourceFilter>(
                    initialValue: _sourceFilter,
                    onSelected: (value) =>
                        setState(() => _sourceFilter = value),
                    itemBuilder: (context) => _ModelSourceFilter.values
                        .map(
                          (value) => PopupMenuItem<_ModelSourceFilter>(
                            value: value,
                            child: Text(_sourceFilterLabel(value, isZh)),
                          ),
                        )
                        .toList(growable: false),
                    child: _ToolbarChip(
                      icon: Icons.filter_alt_rounded,
                      label:
                          '${isZh ? '\u7b5b\u9009' : 'Filter'} · ${_sourceFilterLabel(_sourceFilter, isZh)}',
                    ),
                  ),
                  PopupMenuButton<_ModelSortMode>(
                    initialValue: _sortMode,
                    onSelected: (value) => setState(() => _sortMode = value),
                    itemBuilder: (context) => _ModelSortMode.values
                        .map(
                          (value) => PopupMenuItem<_ModelSortMode>(
                            value: value,
                            child: Text(_sortModeLabel(value, isZh)),
                          ),
                        )
                        .toList(growable: false),
                    child: _ToolbarChip(
                      icon: Icons.swap_vert_rounded,
                      label:
                          '${isZh ? '排序' : 'Sort'} · ${_sortModeLabel(_sortMode, isZh)}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (presets.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isZh ? '内置模型' : 'Built-in Models',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isZh
                      ? '直接从当前服务商的常用模型预设里添加。'
                      : 'Quick add common presets for this provider.',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
                const SizedBox(height: 12),
                ...presets.map((preset) {
                  final exists = service.models.any(
                    (model) =>
                        model.modelKey.trim().toLowerCase() ==
                        preset.modelKey.trim().toLowerCase(),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PresetCard(
                      preset: preset,
                      added: exists,
                      isZh: isZh,
                      onAdd: exists
                          ? null
                          : () => _addPresetModel(service, preset),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isZh ? '我的模型' : 'My Models',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: textMain,
                    ),
                  ),
                  const Spacer(),
                  _CountPill(count: filteredModels.length),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredModels.isEmpty)
                Text(
                  !hasModelFilters
                      ? (isZh
                            ? '还没有模型，请先添加。'
                            : 'No models yet. Add one to get started.')
                      : (isZh ? '没有匹配的模型。' : 'No matching models.'),
                  style: TextStyle(color: textMuted),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = _modelGridColumnCount(
                      constraints.maxWidth,
                    );
                    final viewportHeight = _modelGridViewportHeight(
                      filteredModels.length,
                      crossAxisCount,
                    );
                    final visibleItemCount =
                        crossAxisCount * (crossAxisCount == 1 ? 3 : 2);

                    return SizedBox(
                      height: viewportHeight,
                      child: Scrollbar(
                        thumbVisibility:
                            filteredModels.length > visibleItemCount,
                        child: GridView.builder(
                          primary: false,
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                mainAxisExtent: 132,
                              ),
                          itemCount: filteredModels.length,
                          itemBuilder: (context, index) {
                            final model = filteredModels[index];
                            return _ModelCard(
                              model: model,
                              routeLabels: settings.taskRouteBindings
                                  .where(
                                    (binding) =>
                                        binding.serviceId ==
                                            service.serviceId &&
                                        binding.modelId == model.modelId,
                                  )
                                  .map(
                                    (binding) =>
                                        _routeLabel(binding.routeId, isZh),
                                  )
                                  .toList(growable: false),
                              sourceLabel: _sourceLabel(model.source, isZh),
                              isZh: isZh,
                              onEdit: () => _openEditor(
                                context,
                                ref,
                                service: service,
                                model: model,
                              ),
                              onDelete: () => _deleteModel(context, ref, model),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _syncModels(AiServiceInstance service) async {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final stopwatch = Stopwatch()..start();
    LogManager.instance.info(
      'AI settings model sync started',
      context: buildAiServiceLogContext(service),
    );
    setState(() => _isSyncingModels = true);
    try {
      final registry = ref.read(aiProviderRegistryProvider);
      final adapter = registry.adapterFor(service.adapterKind);
      final discovered = await adapter.listModels(
        service,
        proxySettings: ref.read(aiSettingsProvider).proxySettings,
      );
      final filteredDiscovered = _filterDiscoveredModelsForService(
        service,
        discovered,
      );
      final nextModels = _mergeDiscoveredModels(
        service.models,
        filteredDiscovered,
      );
      final nextService = service.copyWith(
        models: List<AiModelEntry>.unmodifiable(nextModels),
        lastValidatedAt: DateTime.now(),
        lastValidationStatus: AiValidationStatus.success,
        lastValidationMessage: isZh ? '模型同步完成。' : 'Model sync completed.',
      );
      await ref.read(aiSettingsProvider.notifier).upsertService(nextService);
      LogManager.instance.info(
        'AI settings model sync finished',
        context: <String, Object?>{
          ...buildAiServiceLogContext(
            nextService,
            discoveredCount: filteredDiscovered.length,
          ),
          'raw_discovered_count': discovered.length,
          'filtered_discovered_count': filteredDiscovered.length,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        },
      );
      if (!mounted) return;
      showTopToast(context, isZh ? '模型同步完成。' : 'Model sync completed.');
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'AI settings model sync failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          ...buildAiServiceLogContext(service),
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        },
      );
      if (!mounted) return;
      final message = error is UnsupportedError
          ? error.message?.toString()
          : error.toString();
      showTopToast(
        context,
        message?.trim().isNotEmpty == true
            ? message!.trim()
            : (isZh ? '模型同步失败。' : 'Model sync failed.'),
      );
    } finally {
      stopwatch.stop();
      if (mounted) {
        setState(() => _isSyncingModels = false);
      }
    }
  }

  List<AiModelEntry> _mergeDiscoveredModels(
    List<AiModelEntry> currentModels,
    List<AiDiscoveredModel> discoveredModels,
  ) {
    final preserved = currentModels
        .where((model) => model.source != AiModelSource.discovered)
        .toList(growable: true);
    final preservedByKey = <String, AiModelEntry>{
      for (final model in preserved) model.modelKey.trim().toLowerCase(): model,
    };
    final existingDiscoveredByKey = <String, AiModelEntry>{
      for (final model in currentModels.where(
        (item) => item.source == AiModelSource.discovered,
      ))
        model.modelKey.trim().toLowerCase(): model,
    };

    for (final item in discoveredModels) {
      final normalizedKey = item.modelKey.trim().toLowerCase();
      final preservedModel = preservedByKey[normalizedKey];
      if (preservedModel != null) {
        final mergedCapabilities = <AiCapability>{
          ...preservedModel.capabilities,
          ...item.capabilities,
        }.toList(growable: false);
        final index = preserved.indexWhere(
          (model) => model.modelId == preservedModel.modelId,
        );
        if (index >= 0) {
          preserved[index] = preservedModel.copyWith(
            displayName: item.displayName,
            capabilities: List<AiCapability>.unmodifiable(mergedCapabilities),
          );
        }
        continue;
      }

      final existing = existingDiscoveredByKey[normalizedKey];
      preserved.add(
        AiModelEntry(
          modelId: existing?.modelId ?? 'mdl_${generateUid()}',
          displayName: item.displayName,
          modelKey: item.modelKey,
          capabilities: List<AiCapability>.unmodifiable(item.capabilities),
          source: AiModelSource.discovered,
          enabled: existing?.enabled ?? true,
        ),
      );
    }

    preserved.sort(
      (left, right) => left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      ),
    );
    return preserved;
  }

  List<AiDiscoveredModel> _filterDiscoveredModelsForService(
    AiServiceInstance service,
    List<AiDiscoveredModel> discoveredModels,
  ) {
    final ownerAliases = _ownerAliasesForTemplate(service.templateId);
    final modelPatterns = _ownedModelPatternsForTemplate(service.templateId);
    if (ownerAliases.isEmpty && modelPatterns.isEmpty) {
      return discoveredModels;
    }

    return discoveredModels
        .where((model) {
          final ownedBy = model.ownedBy?.trim().toLowerCase() ?? '';
          if (ownedBy.isNotEmpty &&
              ownerAliases.any((alias) => ownedBy.contains(alias))) {
            return true;
          }

          final modelKey = model.modelKey.trim().toLowerCase();
          final displayName = model.displayName.trim().toLowerCase();
          return modelPatterns.any(
            (pattern) =>
                pattern.hasMatch(modelKey) || pattern.hasMatch(displayName),
          );
        })
        .toList(growable: false);
  }

  Set<String> _ownerAliasesForTemplate(String templateId) {
    return switch (templateId.trim()) {
      aiTemplateOpenAi => {'openai'},
      aiTemplateAnthropic => {'anthropic', 'claude'},
      aiTemplateGemini => {'google', 'gemini'},
      aiTemplateDeepSeek => {'deepseek'},
      aiTemplateZhipu => {'zhipu', 'bigmodel', 'glm'},
      aiTemplateMoonshot => {'moonshot', 'kimi'},
      aiTemplateBaichuan => {'baichuan'},
      aiTemplateBailian => {
        'alibaba',
        'aliyun',
        'dashscope',
        'bailian',
        'qwen',
      },
      aiTemplateStepFun => {'stepfun', 'step'},
      aiTemplateDoubao => {'doubao', 'volcengine', 'bytedance', 'ark'},
      aiTemplateZeroOne => {'lingyi', '01', 'yi'},
      aiTemplateMiniMax => {'minimax', 'abab'},
      aiTemplateGrok => {'xai', 'grok'},
      aiTemplateMistral => {'mistral'},
      aiTemplateJina => {'jina'},
      aiTemplatePerplexity => {'perplexity'},
      aiTemplateZhinao => {'360', 'zhinao'},
      aiTemplateHunyuan => {'tencent', 'hunyuan'},
      aiTemplateMiMo => {'xiaomi', 'mimo'},
      _ => const <String>{},
    };
  }

  List<RegExp> _ownedModelPatternsForTemplate(String templateId) {
    return switch (templateId.trim()) {
      aiTemplateOpenAi => <RegExp>[
        RegExp(
          r'^(gpt|o[1-9]|text-embedding|dall-e|whisper|tts)',
          caseSensitive: false,
        ),
      ],
      aiTemplateAnthropic => <RegExp>[RegExp(r'^claude', caseSensitive: false)],
      aiTemplateGemini => <RegExp>[
        RegExp(
          r'^(gemini|text-embedding-004|embedding-001)',
          caseSensitive: false,
        ),
      ],
      aiTemplateDeepSeek => <RegExp>[
        RegExp(r'^deepseek', caseSensitive: false),
      ],
      aiTemplateZhipu => <RegExp>[
        RegExp(r'^(glm|charglm|embedding)', caseSensitive: false),
      ],
      aiTemplateMoonshot => <RegExp>[
        RegExp(r'^(moonshot|kimi)', caseSensitive: false),
      ],
      aiTemplateBaichuan => <RegExp>[
        RegExp(r'^baichuan', caseSensitive: false),
      ],
      aiTemplateBailian => <RegExp>[
        RegExp(r'^(qwen|qwq)', caseSensitive: false),
        RegExp(r'^(text|multimodal)-embedding', caseSensitive: false),
        RegExp(r'^text-rerank', caseSensitive: false),
        RegExp(
          r'^(wanx|cosyvoice|paraformer|sensevoice|sambert)',
          caseSensitive: false,
        ),
      ],
      aiTemplateStepFun => <RegExp>[RegExp(r'^step', caseSensitive: false)],
      aiTemplateDoubao => <RegExp>[RegExp(r'^doubao', caseSensitive: false)],
      aiTemplateZeroOne => <RegExp>[RegExp(r'^yi[-_]', caseSensitive: false)],
      aiTemplateMiniMax => <RegExp>[
        RegExp(r'^(abab|minimax)', caseSensitive: false),
      ],
      aiTemplateGrok => <RegExp>[RegExp(r'^grok', caseSensitive: false)],
      aiTemplateMistral => <RegExp>[
        RegExp(r'^(mistral|pixtral|ministral|codestral)', caseSensitive: false),
      ],
      aiTemplateJina => <RegExp>[RegExp(r'^jina', caseSensitive: false)],
      aiTemplatePerplexity => <RegExp>[
        RegExp(r'^(sonar|r1-1776)', caseSensitive: false),
      ],
      aiTemplateZhinao => <RegExp>[
        RegExp(r'^(360|zhinao)', caseSensitive: false),
      ],
      aiTemplateHunyuan => <RegExp>[RegExp(r'^hunyuan', caseSensitive: false)],
      aiTemplateMiMo => <RegExp>[RegExp(r'^mimo', caseSensitive: false)],
      _ => const <RegExp>[],
    };
  }

  List<AiModelEntry> _buildVisibleModels(
    List<AiModelEntry> models,
    String query,
  ) {
    final filtered = models
        .where((model) {
          final matchesQuery =
              query.isEmpty ||
              model.displayName.toLowerCase().contains(query) ||
              model.modelKey.toLowerCase().contains(query);
          if (!matchesQuery) return false;

          return switch (_sourceFilter) {
            _ModelSourceFilter.all => true,
            _ModelSourceFilter.manual => model.source == AiModelSource.manual,
            _ModelSourceFilter.discovered =>
              model.source == AiModelSource.discovered,
            _ModelSourceFilter.migrated =>
              model.source == AiModelSource.migrated,
            _ModelSourceFilter.disabled => !model.enabled,
          };
        })
        .toList(growable: true);

    filtered.sort(_compareModels);
    return filtered;
  }

  int _compareModels(AiModelEntry left, AiModelEntry right) {
    return switch (_sortMode) {
      _ModelSortMode.nameAsc => left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      ),
      _ModelSortMode.nameDesc => right.displayName.toLowerCase().compareTo(
        left.displayName.toLowerCase(),
      ),
      _ModelSortMode.sourceThenName =>
        _sourceSortWeight(left).compareTo(_sourceSortWeight(right)) != 0
            ? _sourceSortWeight(left).compareTo(_sourceSortWeight(right))
            : left.displayName.toLowerCase().compareTo(
                right.displayName.toLowerCase(),
              ),
    };
  }

  int _sourceSortWeight(AiModelEntry model) {
    if (!model.enabled) return 9;
    return switch (model.source) {
      AiModelSource.manual => 0,
      AiModelSource.discovered => 1,
      AiModelSource.migrated => 2,
    };
  }

  String _sourceFilterLabel(_ModelSourceFilter filter, bool isZh) {
    return switch (filter) {
      _ModelSourceFilter.all => isZh ? '\u5168\u90e8\u6a21\u578b' : 'All Models',
      _ModelSourceFilter.manual => isZh ? '\u624b\u52a8\u6dfb\u52a0' : 'Manual Added',
      _ModelSourceFilter.discovered => isZh ? '\u63a5\u53e3\u540c\u6b65' : 'Synced',
      _ModelSourceFilter.migrated => isZh ? '\u5386\u53f2\u8fc1\u79fb' : 'Imported',
      _ModelSourceFilter.disabled => isZh ? '\u5df2\u5173\u95ed' : 'Disabled',
    };
  }

  String _sortModeLabel(_ModelSortMode mode, bool isZh) {
    return switch (mode) {
      _ModelSortMode.nameAsc => isZh ? '名称 A-Z' : 'Name A-Z',
      _ModelSortMode.nameDesc => isZh ? '名称 Z-A' : 'Name Z-A',
      _ModelSortMode.sourceThenName => isZh ? '按来源' : 'By Source',
    };
  }

  int _modelGridColumnCount(double width) {
    if (width >= 1500) return 4;
    if (width >= 1100) return 3;
    if (width >= 760) return 2;
    return 1;
  }

  double _modelGridViewportHeight(int itemCount, int crossAxisCount) {
    const itemHeight = 132.0;
    const spacing = 10.0;
    final totalRows = (itemCount / crossAxisCount).ceil();
    var visibleRows = totalRows;
    final maxVisibleRows = crossAxisCount == 1 ? 4 : 3;

    if (visibleRows > maxVisibleRows) {
      visibleRows = maxVisibleRows;
    }
    if (visibleRows < 1) {
      visibleRows = 1;
    }

    return (visibleRows * itemHeight) + ((visibleRows - 1) * spacing);
  }

  Future<void> _addPresetModel(
    AiServiceInstance service,
    AiBuiltinModelPreset preset,
  ) async {
    final next = AiModelEntry(
      modelId: 'mdl_${generateUid()}',
      displayName: preset.displayName,
      modelKey: preset.modelKey,
      capabilities: List<AiCapability>.unmodifiable(preset.capabilities),
      source: AiModelSource.manual,
      enabled: true,
    );
    await ref
        .read(aiSettingsProvider.notifier)
        .upsertServiceModel(service.serviceId, next);
    if (!mounted) return;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    showTopToast(context, isZh ? '已添加内置模型。' : 'Built-in model added.');
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    required AiServiceInstance service,
    AiModelEntry? model,
  }) async {
    final result = await showAiModelEditorDialog(
      context,
      service: service,
      initial: model,
    );
    if (result == null) return;
    await ref
        .read(aiSettingsProvider.notifier)
        .upsertServiceModel(service.serviceId, result);
    if (!context.mounted) return;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    showTopToast(context, isZh ? '模型已保存。' : 'Model saved.');
  }

  Future<void> _deleteModel(
    BuildContext context,
    WidgetRef ref,
    AiModelEntry model,
  ) async {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isZh ? '删除模型？' : 'Delete model?'),
        content: Text(
          isZh
              ? '删除后，绑定到这个模型的默认用途会自动解绑。'
              : 'Deleting this model also removes any route binding that uses it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(isZh ? '取消' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isZh ? '删除' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(aiSettingsProvider.notifier)
        .deleteServiceModel(widget.service.serviceId, model.modelId);
  }

  String _sourceLabel(AiModelSource source, bool isZh) {
    return switch (source) {
      AiModelSource.manual => isZh ? '手动' : 'Manual',
      AiModelSource.discovered => isZh ? '同步' : 'Discovered',
      AiModelSource.migrated => isZh ? '迁移' : 'Migrated',
    };
  }

  String _routeLabel(AiTaskRouteId routeId, bool isZh) {
    return switch (routeId) {
      AiTaskRouteId.summary => isZh ? 'AI 总结' : 'AI Summary',
      AiTaskRouteId.analysisReport => isZh ? '分析报告' : 'Analysis Report',
      AiTaskRouteId.quickPrompt => isZh ? '快速提示词' : 'Quick Prompt',
      AiTaskRouteId.embeddingRetrieval =>
        isZh ? 'Embedding 检索' : 'Embedding Retrieval',
    };
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, size: 16),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.added,
    required this.isZh,
    required this.onAdd,
  });

  final AiBuiltinModelPreset preset;
  final bool added;
  final bool isZh;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(preset.modelKey, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final capability in preset.capabilities.where(
                      (capability) => capability != AiCapability.vision,
                    ))
                      _InfoChip(
                        label: switch (capability) {
                          AiCapability.chat => 'Chat',
                          AiCapability.embedding => 'Embedding',
                          AiCapability.vision => 'Vision',
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: onAdd,
            child: Text(
              added ? (isZh ? '已添加' : 'Added') : (isZh ? '添加' : 'Add'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.routeLabels,
    required this.sourceLabel,
    required this.isZh,
    required this.onEdit,
    required this.onDelete,
  });

  final AiModelEntry model;
  final List<String> routeLabels;
  final String sourceLabel;
  final bool isZh;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showModelKey =
        model.displayName.trim().toLowerCase() !=
        model.modelKey.trim().toLowerCase();
    final chipLabels = <String>[
      sourceLabel,
      if (!model.enabled) isZh ? '已禁用' : 'Disabled',
      ...model.capabilities
          .where((capability) => capability != AiCapability.vision)
          .map(
            (capability) => switch (capability) {
              AiCapability.chat => 'Chat',
              AiCapability.embedding => 'Embedding',
              AiCapability.vision => 'Vision',
            },
          ),
      ...routeLabels,
    ];
    final visibleChipLabels = chipLabels.take(3).toList(growable: false);
    final hiddenChipCount = chipLabels.length - visibleChipLabels.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (showModelKey) ...[
                      const SizedBox(height: 2),
                      Text(
                        model.modelKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                    return;
                  }
                  onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Text(isZh ? '编辑' : 'Edit'),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(isZh ? '删除' : 'Delete'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final label in visibleChipLabels)
                _InfoChip(label: label, compact: true),
              if (hiddenChipCount > 0)
                _InfoChip(label: '+$hiddenChipCount', compact: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: compact ? 11 : 12)),
    );
  }
}

class _AiModelEditorDialog extends StatefulWidget {
  const _AiModelEditorDialog({required this.service, this.initial});

  final AiServiceInstance service;
  final AiModelEntry? initial;

  @override
  State<_AiModelEditorDialog> createState() => _AiModelEditorDialogState();
}

class _AiModelEditorDialogState extends State<_AiModelEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _keyController;
  late bool _chat;
  late bool _embedding;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initial?.displayName ?? '',
    );
    _keyController = TextEditingController(
      text: widget.initial?.modelKey ?? '',
    );
    _chat = widget.initial?.capabilities.contains(AiCapability.chat) ?? true;
    _embedding =
        widget.initial?.capabilities.contains(AiCapability.embedding) ?? false;
    _enabled = widget.initial?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final modelKeyLabel = widget.service.templateId == aiTemplateAzureOpenAi
        ? (isZh ? 'Deployment 名称' : 'Deployment Name')
        : (isZh ? '模型 Key' : 'Model Key');
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? (isZh ? '添加模型' : 'Add Model')
            : (isZh ? '编辑模型' : 'Edit Model'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: isZh ? '显示名称' : 'Display Name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyController,
              decoration: InputDecoration(labelText: modelKeyLabel),
            ),
            const SizedBox(height: 16),
            Text(
              isZh ? '能力' : 'Capabilities',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  selected: _chat,
                  label: const Text('Chat'),
                  onSelected: (value) => setState(() => _chat = value),
                ),
                FilterChip(
                  selected: _embedding,
                  label: const Text('Embedding'),
                  onSelected: (value) => setState(() => _embedding = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              title: Text(isZh ? '启用模型' : 'Enable Model'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isZh ? '取消' : 'Cancel'),
        ),
        FilledButton(onPressed: _save, child: Text(isZh ? '保存' : 'Save')),
      ],
    );
  }

  void _save() {
    final modelKey = _keyController.text.trim();
    if (modelKey.isEmpty) return;
    final capabilities = <AiCapability>[
      if (_chat) AiCapability.chat,
      if (_embedding) AiCapability.embedding,
    ];
    if (capabilities.isEmpty) return;
    Navigator.of(context).pop(
      AiModelEntry(
        modelId: widget.initial?.modelId ?? 'mdl_${generateUid()}',
        displayName: _nameController.text.trim().isEmpty
            ? modelKey
            : _nameController.text.trim(),
        modelKey: modelKey,
        capabilities: List<AiCapability>.unmodifiable(capabilities),
        source: widget.initial?.source ?? AiModelSource.manual,
        enabled: _enabled,
      ),
    );
  }
}
