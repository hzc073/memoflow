import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../state/settings/ai_settings_provider.dart';
import '../../i18n/strings.g.dart';

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
  final _formKey = GlobalKey<FormState>();
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
    final selected = await showDialog<String>(
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

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 520,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.t.strings.legacy.msg_model,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setDialogState(() => isEditing = !isEditing),
                            child: Text(
                              isEditing
                                  ? context.t.strings.legacy.msg_done
                                  : context.t.strings.legacy.msg_edit,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          ...options.map(
                            (item) => ListTile(
                              title: Text(item),
                              trailing: isEditing
                                  ? IconButton(
                                      tooltip:
                                          context.t.strings.legacy.msg_delete,
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      onPressed: () => deleteModel(item),
                                    )
                                  : (_isSameModel(item, _model)
                                        ? const Icon(Icons.check_rounded)
                                        : null),
                              onTap: isEditing
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(item),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.add_rounded),
                            title: Text(
                              context.t.strings.legacy.msg_add_custom_model,
                            ),
                            onTap: addCustomModel,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null || !mounted) return;
    _setModel(selected);
  }

  Future<String?> _askCustomModel() async {
    return showDialog<String?>(
      context: context,
      builder: (context) => _CustomModelDialog(initialValue: _model),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_isGenerationMode && !(_formKey.currentState?.validate() ?? false)) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_3(e: e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

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
        decoration: _cardDecoration(card, border, isDark),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _FieldBlock(
                label: isZh ? '接口地址' : 'API URL',
                textMuted: textMuted,
                child: TextFormField(
                  controller: _apiUrlController,
                  enabled: !_saving,
                  onChanged: (_) => _markDirty(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (v) {
                    final raw = (v ?? '').trim();
                    if (raw.isEmpty) {
                      return context.t.strings.legacy.msg_enter_api_url;
                    }
                    final uri = Uri.tryParse(raw);
                    if (uri == null || !(uri.hasScheme && uri.hasAuthority)) {
                      return context.t.strings.legacy.msg_enter_valid_url;
                    }
                    return null;
                  },
                ),
              ),
              Divider(height: 1, color: border),
              _FieldBlock(
                label: isZh ? '接口密钥' : 'API Key',
                textMuted: textMuted,
                child: TextFormField(
                  controller: _apiKeyController,
                  enabled: !_saving,
                  onChanged: (_) => _markDirty(),
                  obscureText: true,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
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
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildEmbeddingCard() {
      return Container(
        decoration: _cardDecoration(card, border, isDark),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _FieldBlock(
                label: isZh ? '接口地址' : 'API URL',
                textMuted: textMuted,
                child: TextFormField(
                  controller: _embeddingBaseUrlController,
                  enabled: !_saving,
                  onChanged: (_) => _markDirty(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Divider(height: 1, color: border),
              _FieldBlock(
                label: isZh ? '接口密钥' : 'API Key',
                textMuted: textMuted,
                child: TextFormField(
                  controller: _embeddingApiKeyController,
                  enabled: !_saving,
                  onChanged: (_) => _markDirty(),
                  obscureText: true,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Divider(height: 1, color: border),
              _FieldBlock(
                label: isZh ? '向量模型' : 'Embedding Model',
                textMuted: textMuted,
                helper: isZh
                    ? '用于检索、召回和相似度匹配'
                    : 'Used for retrieval, recall, and similarity matching.',
                child: TextFormField(
                  controller: _embeddingModelController,
                  enabled: !_saving,
                  onChanged: (_) => _markDirty(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildInfoCard() {
      return Container(
        decoration: _cardDecoration(card, border, isDark),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pageTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textMain,
              ),
            ),
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

    Widget body() {
      return Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              buildInfoCard(),
              const SizedBox(height: 14),
              _isGenerationMode ? buildGenerationCard() : buildEmbeddingCard(),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MemoFlowPalette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: isDark ? 0 : 4,
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          context.t.strings.legacy.msg_save_settings,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: resolveDesktopRouteAutomaticallyImplyLeading(
          context: context,
          automaticallyImplyLeading: true,
        ),
        leading: resolveDesktopRouteDismissalLeading(
          context: context,
          leading: IconButton(
            tooltip: context.t.strings.legacy.msg_back,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(pageTitle),
        centerTitle: false,
      ),
      body: isDark
          ? Stack(
              children: [
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
                body(),
              ],
            )
          : body(),
    );
  }

  BoxDecoration _cardDecoration(Color card, Color border, bool isDark) {
    return BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: border),
      boxShadow: isDark
          ? [
              BoxShadow(
                blurRadius: 28,
                offset: const Offset(0, 16),
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ]
          : [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ],
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
    return AlertDialog(
      title: Text(context.t.strings.legacy.msg_custom_model),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: context.t.strings.legacy.msg_e_g_claude_3_5_sonnet,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _close(null),
          child: Text(context.t.strings.legacy.msg_cancel_2),
        ),
        FilledButton(
          onPressed: () => _close(_controller.text),
          child: Text(context.t.strings.legacy.msg_ok),
        ),
      ],
    );
  }
}
