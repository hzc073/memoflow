import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../data/settings/ai_settings_repository.dart';
import '../../state/ai_settings_provider.dart';

class AiProviderSettingsScreen extends ConsumerStatefulWidget {
  const AiProviderSettingsScreen({super.key});

  @override
  ConsumerState<AiProviderSettingsScreen> createState() => _AiProviderSettingsScreenState();
}

class _AiProviderSettingsScreenState extends ConsumerState<AiProviderSettingsScreen> {
  static const _kModelOptions = <String>[
    'Claude 3.5 Sonnet',
    'Claude 3.5 Haiku',
    'Claude 3 Opus',
    'GPT-4o mini',
    'GPT-4o',
    '自定义…',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _apiUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _promptController;
  ProviderSubscription<AiSettings>? _settingsSubscription;

  var _model = '';
  var _dirty = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiSettingsProvider);
    _apiUrlController = TextEditingController(text: settings.apiUrl);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _promptController = TextEditingController(text: settings.prompt);
    _model = settings.model;

    _settingsSubscription = ref.listenManual<AiSettings>(aiSettingsProvider, (prev, next) {
      if (_dirty || !mounted) return;
      _apiUrlController.text = next.apiUrl;
      _apiKeyController.text = next.apiKey;
      _promptController.text = next.prompt;
      if (_model != next.model) {
        setState(() => _model = next.model);
      }
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

  Future<void> _pickModel() async {
    if (_saving) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(alignment: Alignment.centerLeft, child: Text('模型')),
            ),
            ..._kModelOptions.map(
              (m) => ListTile(
                title: Text(m),
                trailing: m == _model ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(m),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    if (!mounted) return;

    if (selected == '自定义…') {
      final custom = await _askCustomModel();
      if (!mounted) return;
      if (custom == null || custom.trim().isEmpty) return;
      setState(() {
        _model = custom.trim();
        _dirty = true;
      });
      return;
    }

    setState(() {
      _model = selected;
      _dirty = true;
    });
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
      final next = current.copyWith(
        apiUrl: _apiUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        model: _model.trim(),
        prompt: _promptController.text.trim(),
      );
      await ref.read(aiSettingsProvider.notifier).setAll(next);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存设置')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
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
                            if (raw.isEmpty) return '请输入 API URL';
                            final uri = Uri.tryParse(raw);
                            if (uri == null || !(uri.hasScheme && uri.hasAuthority)) return '请输入正确的 URL';
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
                        label: '模型',
                        textMuted: textMuted,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _pickModel,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _model.trim().isEmpty ? '请选择' : _model.trim(),
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
                    Text('提示词 (Prompt)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _promptController,
                      enabled: !_saving,
                      onChanged: (_) => _markDirty(),
                      minLines: 6,
                      maxLines: 10,
                      style: TextStyle(fontWeight: FontWeight.w600, color: textMain, height: 1.35),
                      decoration: InputDecoration(
                        hintText: '用于 AI 总结/报告的默认提示词',
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
                      : const Text('保存设置', style: TextStyle(fontWeight: FontWeight.w800)),
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
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('AI 设置'),
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
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自定义模型'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: '例如：claude-3-5-sonnet-20241022',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => _close(null), child: const Text('取消')),
        FilledButton(onPressed: () => _close(_controller.text), child: const Text('确定')),
      ],
    );
  }
}
