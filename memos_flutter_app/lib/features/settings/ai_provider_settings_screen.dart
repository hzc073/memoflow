import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/settings/ai_settings_repository.dart';
import '../../state/ai_settings_provider.dart';

class AiProviderSettingsScreen extends ConsumerStatefulWidget {
  const AiProviderSettingsScreen({super.key});

  @override
  ConsumerState<AiProviderSettingsScreen> createState() => _AiProviderSettingsScreenState();
}

class _AiProviderSettingsScreenState extends ConsumerState<AiProviderSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _apiUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _promptController;
  ProviderSubscription<AiSettings>? _settingsSubscription;

  var _model = '';
  var _dirty = false;
  var _saving = false;
  var _modelOptions = <String>[];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiSettingsProvider);
    _apiUrlController = TextEditingController(text: settings.apiUrl);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _promptController = TextEditingController(text: settings.prompt);
    _model = settings.model;
    _modelOptions = List<String>.from(settings.modelOptions);

    _settingsSubscription = ref.listenManual<AiSettings>(aiSettingsProvider, (prev, next) {
      if (_dirty || !mounted) return;
      _apiUrlController.text = next.apiUrl;
      _apiKeyController.text = next.apiKey;
      _promptController.text = next.prompt;
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
    _promptController.dispose();
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

  String _modelLabel(BuildContext context, String value) {
    return value;
  }

  Future<void> _pickModel() async {
    if (_saving) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        var isEditing = false;
        var options = List<String>.from(_modelOptions);

        return StatefulBuilder(
          builder: (context, setModalState) {
            void syncOptions(List<String> next, {bool adjustModel = true}) {
              options = _normalizeModelOptions(next);
              setModalState(() {});
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
              if (!context.mounted) return;
              Navigator.of(context).pop(trimmed);
            }

            void deleteModel(String model) {
              final next = options.where((m) => !_isSameModel(m, model)).toList();
              syncOptions(next);
            }

            return SafeArea(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.tr(zh: '模型', en: 'Model')),
                        TextButton(
                          onPressed: () => setModalState(() => isEditing = !isEditing),
                          child: Text(
                            isEditing
                                ? context.tr(zh: '完成', en: 'Done')
                                : context.tr(zh: '编辑', en: 'Edit'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...options.map(
                    (m) => ListTile(
                      title: Text(_modelLabel(context, m)),
                      trailing: isEditing
                          ? IconButton(
                              tooltip: context.tr(zh: '删除', en: 'Delete'),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => deleteModel(m),
                            )
                          : (_isSameModel(m, _model) ? const Icon(Icons.check) : null),
                      onTap: isEditing ? null : () => Navigator.of(context).pop(m),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(context.tr(zh: '添加自定义模型', en: 'Add custom model')),
                    onTap: addCustomModel,
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == null) return;
    if (!mounted) return;
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
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
        prompt: _promptController.text.trim(),
      );
      await ref.read(aiSettingsProvider.notifier).setAll(next);
      if (!mounted) return;
      setState(() => _dirty = false);
      showTopToast(
        context,
        context.tr(zh: '设置已保存', en: 'Settings saved'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '保存失败：$e', en: 'Save failed: $e'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    Widget body() {
      return Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              Container(
                decoration: BoxDecoration(
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
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _FieldBlock(
                        label: 'API URL',
                        textMuted: textMuted,
                        child: TextFormField(
                          controller: _apiUrlController,
                          enabled: !_saving,
                          onChanged: (_) => _markDirty(),
                          style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          validator: (v) {
                            final raw = (v ?? '').trim();
                            if (raw.isEmpty) return context.tr(zh: '请输入 API URL', en: 'Please enter API URL');
                            final uri = Uri.tryParse(raw);
                            if (uri == null || !(uri.hasScheme && uri.hasAuthority)) {
                              return context.tr(zh: '请输入有效的 URL', en: 'Please enter a valid URL');
                            }
                            return null;
                          },
                        ),
                      ),
                      Divider(height: 1, color: border),
                      _FieldBlock(
                        label: 'API Key',
                        textMuted: textMuted,
                        child: TextFormField(
                          controller: _apiKeyController,
                          enabled: !_saving,
                          onChanged: (_) => _markDirty(),
                          obscureText: true,
                          style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Divider(height: 1, color: border),
                      _FieldBlock(
                        label: context.tr(zh: '模型', en: 'Model'),
                        textMuted: textMuted,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _pickModel,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _model.trim().isEmpty
                                        ? context.tr(zh: '请选择', en: 'Select')
                                        : _model.trim(),
                                    style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
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
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
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
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(zh: '提示词 (Prompt)', en: 'Prompt'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _promptController,
                      enabled: !_saving,
                      onChanged: (_) => _markDirty(),
                      minLines: 6,
                      maxLines: 10,
                      style: TextStyle(fontWeight: FontWeight.w600, color: textMain, height: 1.35),
                      decoration: InputDecoration(
                        hintText: context.tr(
                          zh: '用于 AI 总结/报告的默认提示词',
                          en: 'Default prompt for AI summaries/reports',
                        ),
                        hintStyle: TextStyle(color: textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    elevation: isDark ? 0 : 4,
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          context.tr(zh: '保存设置', en: 'Save Settings'),
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
        leading: IconButton(
          tooltip: context.tr(zh: '返回', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr(zh: 'AI 设置', en: 'AI Settings')),
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
                        colors: [
                          const Color(0xFF0B0B0B),
                          bg,
                          bg,
                        ],
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
}

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({required this.label, required this.textMuted, required this.child});

  final String label;
  final Color textMuted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted)),
          const SizedBox(height: 6),
          child,
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
      title: Text(context.tr(zh: '自定义模型', en: 'Custom Model')),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: context.tr(zh: '例如 claude-3-5-sonnet-20241022', en: 'e.g. claude-3-5-sonnet-20241022'),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => _close(null), child: Text(context.tr(zh: '取消', en: 'Cancel'))),
        FilledButton(onPressed: () => _close(_controller.text), child: Text(context.tr(zh: '确定', en: 'OK'))),
      ],
    );
  }
}
