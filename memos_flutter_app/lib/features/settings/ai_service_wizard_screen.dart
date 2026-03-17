import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/ai/ai_settings_log.dart';
import '../../data/logs/log_manager.dart';
import '../../core/uid.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/ai_settings_provider.dart';
import 'ai_provider_logo.dart';
import 'ai_proxy_settings_screen.dart';

class AiServiceWizardScreen extends ConsumerStatefulWidget {
  const AiServiceWizardScreen({super.key});

  @override
  ConsumerState<AiServiceWizardScreen> createState() =>
      _AiServiceWizardScreenState();
}

class _AiServiceWizardScreenState extends ConsumerState<AiServiceWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceConfigKey = GlobalKey();
  final _modelConfigKey = GlobalKey();
  final List<_WizardModelDraft> _draftModels = <_WizardModelDraft>[];
  AiProviderTemplate? _selectedTemplate;
  late final TextEditingController _templateSearchController;
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _headersController;
  late final TextEditingController _modelNameController;
  late final TextEditingController _modelKeyController;
  var _step = 0;
  var _useGenerationDefault = true;
  var _useEmbeddingDefault = false;
  var _chat = true;
  var _embedding = false;
  var _usesSharedProxy = false;

  @override
  void initState() {
    super.initState();
    _templateSearchController = TextEditingController()
      ..addListener(_handleTemplateSearchChanged);
    _nameController = TextEditingController();
    _baseUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _headersController = TextEditingController();
    _modelNameController = TextEditingController();
    _modelKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _templateSearchController
      ..removeListener(_handleTemplateSearchChanged)
      ..dispose();
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _headersController.dispose();
    _modelNameController.dispose();
    _modelKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final proxyConfigured = settings.proxySettings.isConfigured;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(isZh ? '添加服务' : 'Add Service'),
      ),
      body: Stepper(
        currentStep: _step,
        onStepTapped: _handleStepTapped,
        onStepContinue: _continue,
        onStepCancel: _cancel,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                FilledButton(
                  onPressed: details.onStepContinue,
                  child: Text(
                    _step == 2
                        ? (isZh ? '创建服务' : 'Create Service')
                        : (isZh ? '下一步' : 'Next'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: Text(isZh ? '上一步' : 'Back'),
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: Text(isZh ? '选择模板' : 'Choose Template'),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
            content: _TemplatePicker(
              searchController: _templateSearchController,
              searchQuery: _templateSearchController.text,
              selectedTemplateId: _selectedTemplate?.templateId,
              onSelected: (template) => _selectTemplate(template, isZh: isZh),
              onCustomRequested: _showCustomTemplateDialog,
            ),
          ),
          Step(
            title: Text(isZh ? '服务配置' : 'Configure Service'),
            isActive: _step >= 1,
            state: _step > 1 ? StepState.complete : StepState.indexed,
            content: Container(
              key: _serviceConfigKey,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: isZh ? '服务名称' : 'Service Name',
                      ),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? '' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(labelText: 'Base URL'),
                    ),
                    if ((_selectedTemplate?.docsUrl.trim().isNotEmpty ??
                        false)) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              _openDocs(_selectedTemplate!.docsUrl),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(
                            isZh
                                ? '打开 ${localizedAiProviderTemplateDisplayName(_selectedTemplate!, isZh: isZh)} 官方文档'
                                : 'Open ${localizedAiProviderTemplateDisplayName(_selectedTemplate!, isZh: isZh)} documentation',
                          ),
                        ),
                      ),
                    ],
                    if (_selectedTemplate?.requiresApiKey ?? true) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _apiKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'API Key'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _headersController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: isZh ? '额外 Headers' : 'Extra Headers',
                        helperText: isZh
                            ? '\u6bcf\u884c\u4e00\u4e2a\uff0c\u683c\u5f0f key:value\uff0c\u9ed8\u8ba4\u4e3a\u7a7a\u53ef\u4e0d\u586b\u5199'
                            : 'One header per line, formatted as key:value. Optional; leave empty if unused.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _usesSharedProxy,
                      onChanged: (value) {
                        setState(() => _usesSharedProxy = value);
                      },
                      title: Text(context.t.strings.aiProxy.useSharedProxy),
                      subtitle: Text(
                        context.t.strings.aiProxy.useSharedProxyDescription,
                      ),
                    ),
                    if (_usesSharedProxy && !proxyConfigured) ...[
                      const SizedBox(height: 12),
                      _ProxyWarningCard(
                        message: context.t.strings.aiProxy.incompleteWarning,
                        actionLabel: context.t.strings.aiProxy.openSettings,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AiProxySettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Step(
            title: Text(isZh ? '模型与用途' : 'Model & Routes'),
            isActive: _step >= 2,
            content: Container(
              key: _modelConfigKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedTemplate != null &&
                      builtinModelPresetsForTemplate(
                        _selectedTemplate!,
                      ).isNotEmpty) ...[
                    Text(
                      isZh ? '内置模型' : 'Built-in Models',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          builtinModelPresetsForTemplate(_selectedTemplate!)
                              .take(6)
                              .map(
                                (preset) => ActionChip(
                                  label: Text(preset.displayName),
                                  onPressed: () => _applyPreset(preset),
                                ),
                              )
                              .toList(growable: false),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _modelNameController,
                    decoration: InputDecoration(
                      labelText: isZh ? '模型显示名' : 'Model Display Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _modelKeyController,
                    decoration: InputDecoration(
                      labelText:
                          _selectedTemplate?.templateId == aiTemplateAzureOpenAi
                          ? (isZh ? 'Deployment 名称' : 'Deployment Name')
                          : (isZh ? '模型 Key' : 'Model Key'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isZh ? '能力标签' : 'Capabilities',
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
                        onSelected: (value) => setState(() {
                          _chat = value;
                          if (!_chat) _useGenerationDefault = false;
                        }),
                      ),
                      FilterChip(
                        selected: _embedding,
                        label: const Text('Embedding'),
                        onSelected: (value) => setState(() {
                          _embedding = value;
                          if (!_embedding) _useEmbeddingDefault = false;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _useGenerationDefault,
                    onChanged: _chat
                        ? (value) =>
                              setState(() => _useGenerationDefault = value)
                        : null,
                    title: Text(isZh ? '设为生成默认' : 'Use as generation default'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _useEmbeddingDefault,
                    onChanged: _embedding
                        ? (value) =>
                              setState(() => _useEmbeddingDefault = value)
                        : null,
                    title: Text(
                      isZh ? '设为 Embedding 默认' : 'Use as embedding default',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _addDraftModel(isZh: isZh),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(isZh ? '增加模型' : 'Add Model'),
                    ),
                  ),
                  if (_draftModels.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      isZh ? '待创建模型' : 'Models to create',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ..._draftModels.map(
                      (draft) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _QueuedModelCard(
                          draft: draft,
                          isZh: isZh,
                          onRemove: () => _removeDraftModel(draft),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTemplateSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleStepTapped(int step) {
    setState(() => _step = step);
    switch (step) {
      case 1:
        _scrollToKey(_serviceConfigKey);
        break;
      case 2:
        _scrollToKey(_modelConfigKey);
        break;
      default:
        break;
    }
  }

  void _selectTemplate(AiProviderTemplate template, {required bool isZh}) {
    setState(() {
      _selectedTemplate = template;
      _nameController.text = localizedAiProviderTemplateDisplayName(
        template,
        isZh: isZh,
      );
      _baseUrlController.text = template.defaultBaseUrl;
      _headersController.text = _encodeHeaders(template.defaultHeaders);
      _draftModels.clear();
      _modelNameController.clear();
      _modelKeyController.clear();
      _step = 1;
      _chat = true;
      _embedding = false;
      _useGenerationDefault = true;
      _useEmbeddingDefault = false;
    });
    _scrollToKey(_serviceConfigKey);
  }

  Future<void> _showCustomTemplateDialog() async {
    final template = await showDialog<AiProviderTemplate>(
      context: context,
      builder: (context) => const _CustomTemplateTypeDialog(),
    );
    if (!mounted || template == null) return;
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    _selectTemplate(template, isZh: isZh);
  }

  void _continue() async {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    if (_step == 0) {
      if (_selectedTemplate == null) return;
      setState(() => _step = 1);
      _scrollToKey(_serviceConfigKey);
      return;
    }
    if (_step == 1) {
      if (!(_formKey.currentState?.validate() ?? true)) return;
      setState(() => _step = 2);
      _scrollToKey(_modelConfigKey);
      return;
    }
    final template = _selectedTemplate;
    if (template == null) return;
    final modelDrafts = _collectModelDrafts(isZh: isZh);
    if (modelDrafts == null) {
      return;
    }
    final current = ref.read(aiSettingsProvider);
    final mergedHeaders = Map<String, String>.unmodifiable(
      _mergedHeaders(template),
    );
    final matchingService = _findMatchingService(
      current,
      template: template,
      mergedHeaders: mergedHeaders,
    );
    var addedCount = 0;
    var updatedCount = 0;
    final createdModels = <AiModelEntry>[];
    final existingModelsByKey = <String, AiModelEntry>{
      if (matchingService != null)
        for (final candidate in matchingService.models)
          candidate.modelKey.trim().toLowerCase(): candidate,
    };
    var nextModels =
        matchingService?.models.toList(growable: true) ?? <AiModelEntry>[];
    for (final draft in modelDrafts) {
      final existingModel = existingModelsByKey[draft.normalizedKey];
      final nextModel = AiModelEntry(
        modelId: existingModel?.modelId ?? 'mdl_${generateUid()}',
        displayName: draft.displayName,
        modelKey: draft.modelKey,
        capabilities: List<AiCapability>.unmodifiable(draft.capabilities),
        source: existingModel?.source ?? AiModelSource.manual,
        enabled: true,
      );
      createdModels.add(nextModel);
      if (existingModel == null) {
        addedCount += 1;
      } else {
        updatedCount += 1;
      }
      nextModels = _upsertModelEntries(nextModels, nextModel);
    }

    late final AiServiceInstance targetService;
    late final String toastMessage;
    if (matchingService == null) {
      targetService = AiServiceInstance(
        serviceId: 'svc_${generateUid()}',
        templateId: template.templateId,
        adapterKind: template.adapterKind,
        displayName: _nameController.text.trim().isEmpty
            ? localizedAiProviderTemplateDisplayName(template, isZh: isZh)
            : _nameController.text.trim(),
        enabled: true,
        usesSharedProxy: _usesSharedProxy,
        baseUrl: _baseUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        customHeaders: mergedHeaders,
        models: List<AiModelEntry>.unmodifiable(nextModels),
        lastValidatedAt: null,
        lastValidationStatus: AiValidationStatus.unknown,
        lastValidationMessage: null,
      );
      toastMessage = modelDrafts.length == 1
          ? (isZh ? '服务已创建。' : 'Service created.')
          : (isZh
                ? '服务已创建，并添加了 ${modelDrafts.length} 个模型。'
                : 'Service created with ${modelDrafts.length} models.');
    } else {
      targetService = matchingService.copyWith(
        usesSharedProxy: _usesSharedProxy,
        models: List<AiModelEntry>.unmodifiable(nextModels),
      );
      toastMessage = switch ((addedCount, updatedCount)) {
        (0, > 0) => isZh ? '现有服务中的模型已更新。' : 'Existing service models updated.',
        (> 0, 0) =>
          addedCount == 1
              ? (isZh ? '模型已添加到现有服务。' : 'Model added to existing service.')
              : (isZh
                    ? '已向现有服务添加 $addedCount 个模型。'
                    : '$addedCount models added to existing service.'),
        _ =>
          isZh
              ? '现有服务已同步：新增 $addedCount 个，更新 $updatedCount 个模型。'
              : 'Existing service synced: $addedCount added, $updatedCount updated.',
      };
    }

    final services = _upsertServiceEntries(current.services, targetService);
    final replacementByRoute = <AiTaskRouteId, AiTaskRouteBinding>{};
    for (var index = 0; index < modelDrafts.length; index++) {
      final draft = modelDrafts[index];
      final model = createdModels[index];
      if (draft.useGenerationDefault) {
        replacementByRoute[AiTaskRouteId.summary] = AiTaskRouteBinding(
          routeId: AiTaskRouteId.summary,
          serviceId: targetService.serviceId,
          modelId: model.modelId,
          capability: AiCapability.chat,
        );
        replacementByRoute[AiTaskRouteId.analysisReport] = AiTaskRouteBinding(
          routeId: AiTaskRouteId.analysisReport,
          serviceId: targetService.serviceId,
          modelId: model.modelId,
          capability: AiCapability.chat,
        );
        replacementByRoute[AiTaskRouteId.quickPrompt] = AiTaskRouteBinding(
          routeId: AiTaskRouteId.quickPrompt,
          serviceId: targetService.serviceId,
          modelId: model.modelId,
          capability: AiCapability.chat,
        );
      }
      if (draft.useEmbeddingDefault) {
        replacementByRoute[AiTaskRouteId.embeddingRetrieval] =
            AiTaskRouteBinding(
              routeId: AiTaskRouteId.embeddingRetrieval,
              serviceId: targetService.serviceId,
              modelId: model.modelId,
              capability: AiCapability.embedding,
            );
      }
    }
    final replacements = replacementByRoute.values.toList(growable: false);
    final routeIds = replacements.map((binding) => binding.routeId).toSet();
    final bindings =
        current.taskRouteBindings
            .where((binding) => !routeIds.contains(binding.routeId))
            .toList(growable: true)
          ..addAll(replacements);

    await ref
        .read(aiSettingsProvider.notifier)
        .setAll(
          current.copyWith(
            services: List<AiServiceInstance>.unmodifiable(services),
            taskRouteBindings: List<AiTaskRouteBinding>.unmodifiable(bindings),
          ),
        );
    LogManager.instance.info(
      'AI settings wizard completed',
      context: <String, Object?>{
        ...buildAiServiceLogContext(
          targetService,
          template: template,
          model: createdModels.isEmpty ? null : createdModels.last,
          discoveredCount: modelDrafts.length,
          routeCount: replacements.length,
          reusedExistingService: matchingService != null,
        ),
        'step_count': 3,
      },
    );
    if (!mounted) return;
    showTopToast(context, toastMessage);
    Navigator.of(context).pop();
  }

  void _cancel() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step -= 1);
  }

  void _scrollToKey(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _applyPreset(AiBuiltinModelPreset preset) {
    setState(() {
      _modelNameController.text = preset.displayName;
      _modelKeyController.text = preset.modelKey;
      _chat = preset.capabilities.contains(AiCapability.chat);
      _embedding = preset.capabilities.contains(AiCapability.embedding);
      _useGenerationDefault = _chat;
      _useEmbeddingDefault = _embedding && !_chat;
    });
  }

  void _addDraftModel({required bool isZh}) {
    final draft = _buildCurrentDraft(isZh: isZh);
    if (draft == null) return;
    setState(() {
      _upsertDraftModel(draft);
      _modelNameController.clear();
      _modelKeyController.clear();
      _useGenerationDefault = false;
      _useEmbeddingDefault = false;
    });
    showTopToast(
      context,
      isZh ? '模型已加入待创建列表。' : 'Model added to pending list.',
    );
  }

  void _removeDraftModel(_WizardModelDraft draft) {
    setState(() {
      _draftModels.removeWhere(
        (item) => item.normalizedKey == draft.normalizedKey,
      );
    });
  }

  _WizardModelDraft? _buildCurrentDraft({required bool isZh}) {
    final modelKey = _modelKeyController.text.trim();
    final displayName = _modelNameController.text.trim();
    if (modelKey.isEmpty) {
      showTopToast(
        context,
        isZh ? '请先填写模型 Key。' : 'Please enter a model key first.',
      );
      return null;
    }
    if (!_chat && !_embedding) {
      showTopToast(
        context,
        isZh ? '请至少选择一种模型能力。' : 'Select at least one model capability.',
      );
      return null;
    }
    final capabilities = <AiCapability>[
      if (_chat) AiCapability.chat,
      if (_embedding) AiCapability.embedding,
    ];
    return _WizardModelDraft(
      displayName: displayName.isEmpty ? modelKey : displayName,
      modelKey: modelKey,
      capabilities: List<AiCapability>.unmodifiable(capabilities),
      useGenerationDefault: _useGenerationDefault,
      useEmbeddingDefault: _useEmbeddingDefault,
    );
  }

  List<_WizardModelDraft>? _collectModelDrafts({required bool isZh}) {
    final drafts = List<_WizardModelDraft>.from(_draftModels);
    final hasCurrentInput =
        _modelNameController.text.trim().isNotEmpty ||
        _modelKeyController.text.trim().isNotEmpty;
    if (hasCurrentInput) {
      final currentDraft = _buildCurrentDraft(isZh: isZh);
      if (currentDraft == null) return null;
      _upsertDraftModel(currentDraft, drafts: drafts);
    }
    if (drafts.isEmpty) {
      showTopToast(
        context,
        isZh ? '请至少添加一个模型。' : 'Please add at least one model.',
      );
      return null;
    }
    return List<_WizardModelDraft>.unmodifiable(drafts);
  }

  void _upsertDraftModel(
    _WizardModelDraft draft, {
    List<_WizardModelDraft>? drafts,
  }) {
    final target = drafts ?? _draftModels;
    if (draft.useGenerationDefault) {
      for (var index = 0; index < target.length; index++) {
        target[index] = target[index].copyWith(useGenerationDefault: false);
      }
    }
    if (draft.useEmbeddingDefault) {
      for (var index = 0; index < target.length; index++) {
        target[index] = target[index].copyWith(useEmbeddingDefault: false);
      }
    }
    final existingIndex = target.indexWhere(
      (item) => item.normalizedKey == draft.normalizedKey,
    );
    if (existingIndex >= 0) {
      target[existingIndex] = draft;
      return;
    }
    target.add(draft);
  }

  Future<void> _openDocs(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      final isZh =
          Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
      showTopToast(context, isZh ? '无法打开链接。' : 'Unable to open link.');
    }
  }

  String _encodeHeaders(Map<String, String> headers) {
    if (headers.isEmpty) return '';
    return headers.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join('\n');
  }

  Map<String, String> _mergedHeaders(AiProviderTemplate template) {
    return <String, String>{...template.defaultHeaders, ..._parseHeaders()};
  }

  AiServiceInstance? _findMatchingService(
    AiSettings settings, {
    required AiProviderTemplate template,
    required Map<String, String> mergedHeaders,
  }) {
    final targetBaseUrl = _baseUrlController.text.trim();
    final targetApiKey = _apiKeyController.text.trim();
    for (final service in settings.services) {
      if (service.templateId != template.templateId) continue;
      if (service.baseUrl.trim() != targetBaseUrl) continue;
      if (service.apiKey.trim() != targetApiKey) continue;
      if (!_mapsEqual(service.customHeaders, mergedHeaders)) continue;
      return service;
    }
    return null;
  }

  List<AiServiceInstance> _upsertServiceEntries(
    List<AiServiceInstance> services,
    AiServiceInstance nextService,
  ) {
    final next = <AiServiceInstance>[];
    var replaced = false;
    for (final service in services) {
      if (service.serviceId == nextService.serviceId) {
        next.add(nextService);
        replaced = true;
      } else {
        next.add(service);
      }
    }
    if (!replaced) {
      next.add(nextService);
    }
    return next;
  }

  List<AiModelEntry> _upsertModelEntries(
    List<AiModelEntry> models,
    AiModelEntry nextModel,
  ) {
    final next = <AiModelEntry>[];
    var replaced = false;
    for (final model in models) {
      if (model.modelId == nextModel.modelId) {
        next.add(nextModel);
        replaced = true;
      } else {
        next.add(model);
      }
    }
    if (!replaced) {
      next.add(nextModel);
    }
    return next;
  }

  bool _mapsEqual(Map<String, String> left, Map<String, String> right) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  Map<String, String> _parseHeaders() {
    final next = <String, String>{};
    for (final line in _headersController.text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final separator = trimmed.indexOf(':');
      if (separator <= 0) continue;
      final key = trimmed.substring(0, separator).trim();
      final value = trimmed.substring(separator + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      next[key] = value;
    }
    return next;
  }
}

class _ProxyWarningCard extends StatelessWidget {
  const _ProxyWarningCard({
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 8),
                TextButton(onPressed: onTap, child: Text(actionLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardModelDraft {
  const _WizardModelDraft({
    required this.displayName,
    required this.modelKey,
    required this.capabilities,
    required this.useGenerationDefault,
    required this.useEmbeddingDefault,
  });

  final String displayName;
  final String modelKey;
  final List<AiCapability> capabilities;
  final bool useGenerationDefault;
  final bool useEmbeddingDefault;

  String get normalizedKey => modelKey.trim().toLowerCase();

  _WizardModelDraft copyWith({
    String? displayName,
    String? modelKey,
    List<AiCapability>? capabilities,
    bool? useGenerationDefault,
    bool? useEmbeddingDefault,
  }) {
    return _WizardModelDraft(
      displayName: displayName ?? this.displayName,
      modelKey: modelKey ?? this.modelKey,
      capabilities: capabilities ?? this.capabilities,
      useGenerationDefault: useGenerationDefault ?? this.useGenerationDefault,
      useEmbeddingDefault: useEmbeddingDefault ?? this.useEmbeddingDefault,
    );
  }
}

class _QueuedModelCard extends StatelessWidget {
  const _QueuedModelCard({
    required this.draft,
    required this.isZh,
    required this.onRemove,
  });

  final _WizardModelDraft draft;
  final bool isZh;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
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
                      draft.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft.modelKey,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                tooltip: isZh ? '移除' : 'Remove',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final capability in draft.capabilities)
                _DraftBadge(
                  label: switch (capability) {
                    AiCapability.chat => 'Chat',
                    AiCapability.embedding => 'Embedding',
                    AiCapability.vision => 'Vision',
                  },
                ),
              if (draft.useGenerationDefault)
                _DraftBadge(label: isZh ? '生成默认' : 'Generation Default'),
              if (draft.useEmbeddingDefault)
                _DraftBadge(label: isZh ? 'Embedding 默认' : 'Embedding Default'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DraftBadge extends StatelessWidget {
  const _DraftBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({
    required this.searchController,
    required this.searchQuery,
    required this.selectedTemplateId,
    required this.onSelected,
    required this.onCustomRequested,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final String? selectedTemplateId;
  final ValueChanged<AiProviderTemplate> onSelected;
  final VoidCallback onCustomRequested;

  @override
  Widget build(BuildContext context) {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final templates = aiProviderTemplates
        .where((template) => template.group != AiProviderTemplateGroup.custom)
        .where((template) {
          if (normalizedQuery.isEmpty) return true;
          final localizedName = localizedAiProviderTemplateDisplayName(
            template,
            isZh: isZh,
          ).toLowerCase();
          return localizedName.contains(normalizedQuery) ||
              template.displayName.toLowerCase().contains(normalizedQuery) ||
              template.templateId.toLowerCase().contains(normalizedQuery) ||
              template.defaultBaseUrl.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
    final selectedTemplate = selectedTemplateId == null
        ? null
        : findAiProviderTemplate(selectedTemplateId!);
    final isCustomSelected =
        selectedTemplate?.group == AiProviderTemplateGroup.custom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 960.0;
        final spacing = 12.0;
        final columns = maxWidth >= 1180
            ? 4
            : maxWidth >= 860
            ? 3
            : maxWidth >= 560
            ? 2
            : 1;
        final itemWidth = (maxWidth - spacing * (columns - 1)) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: isZh ? '搜索服务商' : 'Search providers',
                suffixIcon: normalizedQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isZh
                  ? '所有服务商都在这里一起显示，最后一张卡用于添加自定义接入。'
                  : 'All providers are shown together. Use the last tile for custom integrations.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (templates.isEmpty) ...[
              Text(
                isZh ? '未找到匹配的服务商。' : 'No matching providers found.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final template in templates)
                  SizedBox(
                    width: itemWidth,
                    child: _TemplateChoiceCard(
                      template: template,
                      isSelected: template.templateId == selectedTemplateId,
                      isZh: isZh,
                      onTap: () => onSelected(template),
                    ),
                  ),
                SizedBox(
                  width: itemWidth,
                  child: _CustomTemplateEntryCard(
                    isZh: isZh,
                    isSelected: isCustomSelected,
                    selectedTemplate: isCustomSelected
                        ? selectedTemplate
                        : null,
                    onTap: onCustomRequested,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CustomTemplateEntryCard extends StatelessWidget {
  const _CustomTemplateEntryCard({
    required this.isZh,
    required this.isSelected,
    required this.selectedTemplate,
    required this.onTap,
  });

  final bool isZh;
  final bool isSelected;
  final AiProviderTemplate? selectedTemplate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeLabel = selectedTemplate == null
        ? (isZh
              ? '可选 OpenAI / Anthropic / Gemini'
              : 'OpenAI-compatible / Anthropic / Gemini')
        : localizedAiProviderTemplateDisplayName(selectedTemplate!, isZh: isZh);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.10)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(
                      alpha: isDark ? 0.45 : 0.65,
                    ),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.add_link_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isZh ? '添加自定义模型' : 'Add Custom Model',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 20,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in <String>['OpenAI', 'Anthropic', 'Gemini'])
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: isDark ? 0.35 : 0.55,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isZh
                    ? '先选择协议类型，再配置 URL、API Key 和模型。'
                    : 'Pick a protocol first, then configure URL, API key, and models.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomTemplateTypeDialog extends StatelessWidget {
  const _CustomTemplateTypeDialog();

  @override
  Widget build(BuildContext context) {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final options = <({AiProviderTemplate template, String description})>[
      (
        template: findAiProviderTemplate(aiTemplateCustomOpenAi)!,
        description: isZh
            ? '适用于 OpenAI 兼容网关、代理或第三方 API。'
            : 'For OpenAI-compatible gateways, proxies, and third-party APIs.',
      ),
      (
        template: findAiProviderTemplate(aiTemplateCustomAnthropic)!,
        description: isZh
            ? '适用于 Claude / Anthropic 协议风格 API。'
            : 'For Claude / Anthropic-style APIs.',
      ),
      (
        template: findAiProviderTemplate(aiTemplateCustomGemini)!,
        description: isZh
            ? '适用于 Gemini / Google AI 协议风格 API。'
            : 'For Gemini / Google AI-style APIs.',
      ),
    ];

    return AlertDialog(
      title: Text(isZh ? '选择自定义协议类型' : 'Choose Custom Provider Type'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isZh
                  ? '先确定协议类型，下一步再配置 URL、API Key、Headers 和模型。'
                  : 'Pick a protocol first. You can configure URL, API key, headers, and models in the next steps.',
            ),
            const SizedBox(height: 12),
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  leading: AiProviderLogo(
                    template: option.template,
                    size: 40,
                    iconSize: 22,
                  ),
                  title: Text(
                    localizedAiProviderTemplateDisplayName(
                      option.template,
                      isZh: isZh,
                    ),
                  ),
                  subtitle: Text(option.description),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(option.template),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isZh ? '取消' : 'Cancel'),
        ),
      ],
    );
  }
}

class _TemplateChoiceCard extends StatelessWidget {
  const _TemplateChoiceCard({
    required this.template,
    required this.isSelected,
    required this.isZh,
    required this.onTap,
  });

  final AiProviderTemplate template;
  final bool isSelected;
  final bool isZh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final title = localizedAiProviderTemplateDisplayName(template, isZh: isZh);
    final subtitle = template.defaultBaseUrl.trim().isNotEmpty
        ? template.defaultBaseUrl
        : (isZh ? '手动配置接入地址' : 'Configure endpoint manually');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.10)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(
                      alpha: isDark ? 0.45 : 0.65,
                    ),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AiProviderLogo(template: template, size: 42, iconSize: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
