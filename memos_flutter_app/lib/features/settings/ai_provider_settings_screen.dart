import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/top_toast.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../i18n/strings.g.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform/widgets/platform_primary_action.dart';
import '../../state/settings/ai_settings_provider.dart';
import 'settings_ui.dart';

enum AiProviderSettingsMode { generation, embedding }

class AiProviderSettingsScreen extends ConsumerStatefulWidget {
  const AiProviderSettingsScreen({
    super.key,
    this.mode = AiProviderSettingsMode.generation,
  });

  final AiProviderSettingsMode mode;

  @override
  ConsumerState<AiProviderSettingsScreen> createState() =>
      _AiProviderSettingsScreenState();
}

class _AiProviderSettingsScreenState
    extends ConsumerState<AiProviderSettingsScreen> {
  late final TextEditingController _apiUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _embeddingBaseUrlController;
  late final TextEditingController _embeddingApiKeyController;
  late final TextEditingController _embeddingModelController;
  ProviderSubscription<AiSettings>? _settingsSubscription;

  var _model = '';
  var _dirty = false;
  var _saving = false;
  var _modelOptions = <String>[];
  String? _apiUrlError;

  bool get _isGenerationMode =>
      widget.mode == AiProviderSettingsMode.generation;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiSettingsProvider);
    _apiUrlController = TextEditingController(text: settings.apiUrl);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _embeddingBaseUrlController = TextEditingController(
      text: settings.embeddingBaseUrl,
    );
    _embeddingApiKeyController = TextEditingController(
      text: settings.embeddingApiKey,
    );
    _embeddingModelController = TextEditingController(
      text: settings.embeddingModel,
    );
    _model = settings.model;
    _modelOptions = List<String>.from(settings.modelOptions);

    _settingsSubscription = ref.listenManual<AiSettings>(aiSettingsProvider, (
      prev,
      next,
    ) {
      if (_dirty || !mounted) return;
      _apiUrlController.text = next.apiUrl;
      _apiKeyController.text = next.apiKey;
      _embeddingBaseUrlController.text = next.embeddingBaseUrl;
      _embeddingApiKeyController.text = next.embeddingApiKey;
      _embeddingModelController.text = next.embeddingModel;
      setState(() {
        _model = next.model;
        _modelOptions = List<String>.from(next.modelOptions);
        _apiUrlError = null;
      });
    });
  }

  @override
  void dispose() {
    _settingsSubscription?.close();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _embeddingBaseUrlController.dispose();
    _embeddingApiKeyController.dispose();
    _embeddingModelController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  void _onApiUrlChanged(String _) {
    if (_apiUrlError != null) {
      setState(() => _apiUrlError = null);
    }
    _markDirty();
  }

  bool _validateGenerationApiUrl() {
    final raw = _apiUrlController.text.trim();
    final uri = Uri.tryParse(raw);
    final error = raw.isEmpty
        ? context.t.strings.legacy.msg_enter_api_url
        : (uri != null && uri.hasScheme && uri.hasAuthority)
        ? null
        : context.t.strings.legacy.msg_enter_valid_url;
    if (_apiUrlError != error) {
      setState(() => _apiUrlError = error);
    }
    return error == null;
  }

  bool _isSameModel(String a, String b) {
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }

  bool _containsModel(List<String> options, String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return options.any((option) => option.trim().toLowerCase() == normalized);
  }

  List<String> _normalizeModelOptions(Iterable<String> options) {
    final seen = <String>{};
    final result = <String>[];
    for (final option in options) {
      final trimmed = option.trim();
      if (trimmed.isEmpty) continue;
      final normalized = trimmed.toLowerCase();
      if (seen.add(normalized)) {
        result.add(trimmed);
      }
    }
    return result;
  }

  void _setModelOptions(List<String> next, {bool adjustModel = true}) {
    if (!mounted) return;
    final normalized = _normalizeModelOptions(next);
    setState(() {
      _modelOptions = normalized;
      _dirty = true;
      if (adjustModel && !_containsModel(normalized, _model)) {
        _model = normalized.isNotEmpty ? normalized.first : '';
      }
    });
  }

  void _setModel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || !mounted) return;
    setState(() {
      _model = trimmed;
      _dirty = true;
      if (!_containsModel(_modelOptions, trimmed)) {
        _modelOptions = _normalizeModelOptions([trimmed, ..._modelOptions]);
      }
    });
  }

  Future<void> _pickModel() async {
    if (_saving) return;
    final selected = await showPlatformDialog<String>(
      context: context,
      builder: (dialogContext) {
        var isEditing = false;
        var options = List<String>.from(_modelOptions);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void syncOptions(List<String> next, {bool adjustModel = true}) {
              options = _normalizeModelOptions(next);
              setDialogState(() {});
              _setModelOptions(options, adjustModel: adjustModel);
            }

            Future<void> addCustomModel() async {
              final custom = await _askCustomModel();
              if (!mounted) return;
              final trimmed = custom?.trim() ?? '';
              if (trimmed.isEmpty) return;
              if (!_containsModel(options, trimmed)) {
                syncOptions([trimmed, ...options], adjustModel: false);
              }
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(trimmed);
            }

            void deleteModel(String model) {
              final next = options
                  .where((item) => !_isSameModel(item, model))
                  .toList();
              syncOptions(next);
            }

            return SettingsFormDialog(
              maxWidth: 420,
              maxHeightFactor: 0.72,
              title: Row(
                children: [
                  Expanded(child: Text(context.t.strings.legacy.msg_model)),
                  SettingsActionPill(
                    label: isEditing
                        ? context.t.strings.legacy.msg_done
                        : context.t.strings.legacy.msg_edit,
                    icon: isEditing ? Icons.check_rounded : Icons.edit_outlined,
                    onPressed: () =>
                        setDialogState(() => isEditing = !isEditing),
                  ),
                ],
              ),
              children: [
                SettingsSection(
                  children: [
                    if (isEditing)
                      for (final item in options)
                        SettingsNavigationRow(
                          label: item,
                          trailingIcon: Icons.delete_outline_rounded,
                          onTap: () => deleteModel(item),
                        )
                    else
                      SettingsSingleChoiceList<String>(
                        value: _model,
                        options: [
                          for (final item in options)
                            SettingsChoiceOption<String>(
                              value: item,
                              label: item,
                            ),
                        ],
                        onChanged: (item) =>
                            Navigator.of(dialogContext).pop(item),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SettingsAction(
                    onPressed: addCustomModel,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.t.strings.legacy.msg_add_custom_model),
                    variant: PlatformPrimaryActionVariant.outlined,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null || !mounted) return;
    _setModel(selected);
  }

  Future<String?> _askCustomModel() async {
    return showPlatformDialog<String?>(
      context: context,
      builder: (context) => _CustomModelDialog(initialValue: _model),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_isGenerationMode && !_validateGenerationApiUrl()) {
      return;
    }

    setState(() => _saving = true);
    try {
      final current = ref.read(aiSettingsProvider);
      final model = _model.trim();
      final normalizedOptions = _normalizeModelOptions(_modelOptions);
      final options = _containsModel(normalizedOptions, model) || model.isEmpty
          ? normalizedOptions
          : _normalizeModelOptions([model, ...normalizedOptions]);
      final next = current.copyWith(
        apiUrl: _apiUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        model: model,
        modelOptions: options,
        embeddingBaseUrl: _embeddingBaseUrlController.text.trim(),
        embeddingApiKey: _embeddingApiKeyController.text.trim(),
        embeddingModel: _embeddingModelController.text.trim(),
      );
      await ref.read(aiSettingsProvider.notifier).setAll(next);
      if (!mounted) return;
      setState(() => _dirty = false);
      showTopToast(context, context.t.strings.legacy.msg_settings_saved);
    } catch (e) {
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_save_failed_3(e: e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final tokens = settingsPageTokens(context);
    final card = tokens.card;
    final textMain = tokens.textMain;
    final textMuted = tokens.textMuted;
    final border = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.65);

    final pageTitle = _isGenerationMode
        ? (isZh ? 'LLM 模型' : 'LLM Model')
        : (isZh ? '向量模型' : 'Embedding Model');
    final pageDescription = _isGenerationMode
        ? (isZh
              ? '用于总结、结构化分析与最终生成。'
              : 'Used for summaries, structured analysis, and final generation.')
        : (isZh
              ? '用于检索、召回、相似度匹配与证据引用。'
              : 'Used for retrieval, recall, similarity matching, and evidence links.');
    final compatibilityHint = isZh
        ? 'LLM 模型和向量模型可以共用同一个接口与密钥，也可以分别配置。如果当前 LLM 服务不支持 embeddings，请在这里单独配置支持向量的服务。'
        : 'LLM and embedding models can share the same endpoint and API key, or use separate ones. If your current LLM service does not support embeddings, configure a dedicated embedding service here.';

    Widget buildGenerationCard() {
      return Container(
        decoration: _cardDecoration(card, border),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: SettingsDialogTextField(
                label: isZh ? '接口地址' : 'API URL',
                controller: _apiUrlController,
                enabled: !_saving,
                errorText: _apiUrlError,
                onChanged: _onApiUrlChanged,
              ),
            ),
            Divider(height: 1, color: border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: SettingsDialogTextField(
                label: isZh ? '接口密钥' : 'API Key',
                controller: _apiKeyController,
                enabled: !_saving,
                obscureText: true,
                onChanged: (_) => _markDirty(),
              ),
            ),
            Divider(height: 1, color: border),
            _FieldBlock(
              label: isZh ? 'LLM 模型' : 'LLM Model',
              textMuted: textMuted,
              helper: isZh
                  ? '用于总结与结构化生成'
                  : 'Used for summaries and structured generation.',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _pickModel,
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _model.trim().isEmpty
                              ? context.t.strings.legacy.msg_select
                              : _model.trim(),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textMain,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded, color: textMuted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildEmbeddingCard() {
      return Container(
        decoration: _cardDecoration(card, border),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: SettingsDialogTextField(
                label: isZh ? '接口地址' : 'API URL',
                controller: _embeddingBaseUrlController,
                enabled: !_saving,
                onChanged: (_) => _markDirty(),
              ),
            ),
            Divider(height: 1, color: border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: SettingsDialogTextField(
                label: isZh ? '接口密钥' : 'API Key',
                controller: _embeddingApiKeyController,
                enabled: !_saving,
                obscureText: true,
                onChanged: (_) => _markDirty(),
              ),
            ),
            Divider(height: 1, color: border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: SettingsDialogTextField(
                label: isZh ? '向量模型' : 'Embedding Model',
                controller: _embeddingModelController,
                enabled: !_saving,
                helperText: isZh
                    ? '用于检索、召回和相似度匹配'
                    : 'Used for retrieval, recall, and similarity matching.',
                onChanged: (_) => _markDirty(),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildInfoCard() {
      return Container(
        decoration: _cardDecoration(card, border),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsContentHeader(title: pageTitle),
            const SizedBox(height: 6),
            Text(
              pageDescription,
              style: TextStyle(fontSize: 13, height: 1.55, color: textMuted),
            ),
            if (!_isGenerationMode) ...[
              const SizedBox(height: 10),
              Text(
                compatibilityHint,
                style: TextStyle(fontSize: 13, height: 1.55, color: textMuted),
              ),
            ],
          ],
        ),
      );
    }

    return SettingsPage(
      title: Text(pageTitle),
      children: [
        buildInfoCard(),
        const SizedBox(height: 14),
        _isGenerationMode ? buildGenerationCard() : buildEmbeddingCard(),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SettingsAction(
            onPressed: _saving ? null : _save,
            label: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.t.strings.legacy.msg_save_settings),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration(Color card, Color border) {
    return BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({
    required this.label,
    required this.textMuted,
    required this.child,
    this.helper,
  });

  final String label;
  final Color textMuted;
  final Widget child;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 6),
          child,
          if (helper != null && helper!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              helper!,
              style: TextStyle(fontSize: 12, height: 1.45, color: textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomModelDialog extends StatefulWidget {
  const _CustomModelDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_CustomModelDialog> createState() => _CustomModelDialogState();
}

class _CustomModelDialogState extends State<_CustomModelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close(String? result) {
    FocusScope.of(context).unfocus();
    context.safePop(result);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFormDialog(
      title: Text(context.t.strings.legacy.msg_custom_model),
      actions: [
        SettingsDialogAction(
          onPressed: () => _close(null),
          label: Text(context.t.strings.legacy.msg_cancel_2),
        ),
        SettingsDialogAction(
          onPressed: () => _close(_controller.text),
          label: Text(context.t.strings.legacy.msg_ok),
          variant: PlatformPrimaryActionVariant.filled,
        ),
      ],
      children: [
        SettingsDialogTextField(
          label: context.t.strings.legacy.msg_model,
          controller: _controller,
          hint: context.t.strings.legacy.msg_e_g_claude_3_5_sonnet,
        ),
      ],
    );
  }
}
