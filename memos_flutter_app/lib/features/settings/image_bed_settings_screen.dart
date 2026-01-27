import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/image_bed_url.dart';
import '../../core/memoflow_palette.dart';
import '../../data/models/image_bed_settings.dart';
import '../../state/image_bed_settings_provider.dart';

class ImageBedSettingsScreen extends ConsumerStatefulWidget {
  const ImageBedSettingsScreen({super.key});

  @override
  ConsumerState<ImageBedSettingsScreen> createState() => _ImageBedSettingsScreenState();
}

class _ImageBedSettingsScreenState extends ConsumerState<ImageBedSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _strategyController = TextEditingController();
  ProviderSubscription<ImageBedSettings>? _settingsSubscription;

  var _provider = ImageBedProvider.lskyPro;
  var _retryCount = ImageBedSettings.defaults.retryCount;
  var _dirty = false;

  static const int _minRetry = 0;
  static const int _maxRetry = 10;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(imageBedSettingsProvider);
    _applySettings(settings);
    _settingsSubscription = ref.listenManual<ImageBedSettings>(imageBedSettingsProvider, (prev, next) {
      if (_dirty || !mounted) return;
      _applySettings(next);
    });
  }

  @override
  void dispose() {
    _settingsSubscription?.close();
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _strategyController.dispose();
    super.dispose();
  }

  void _applySettings(ImageBedSettings settings) {
    _provider = settings.provider;
    _retryCount = settings.retryCount;
    _baseUrlController.text = settings.baseUrl;
    _emailController.text = settings.email;
    _passwordController.text = settings.password;
    _strategyController.text = settings.strategyId ?? '';
    setState(() {});
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  String _providerLabel(BuildContext context, ImageBedProvider provider) {
    return context.tr(zh: '兰空图床 (Lsky Pro)', en: 'Lsky Pro');
  }

  Future<void> _selectProvider() async {
    final selected = await showModalBottomSheet<ImageBedProvider>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(_providerLabel(context, ImageBedProvider.lskyPro)),
                trailing: _provider == ImageBedProvider.lskyPro ? const Icon(Icons.check) : null,
                onTap: () => context.safePop(ImageBedProvider.lskyPro),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() => _provider = selected);
    _markDirty();
    ref.read(imageBedSettingsProvider.notifier).setProvider(selected);
  }

  void _updateRetry(int delta) {
    final next = (_retryCount + delta).clamp(_minRetry, _maxRetry);
    if (next == _retryCount) return;
    setState(() => _retryCount = next);
    _markDirty();
    ref.read(imageBedSettingsProvider.notifier).setRetryCount(next);
  }

  void _normalizeBaseUrl() {
    final raw = _baseUrlController.text.trim();
    if (raw.isEmpty) return;
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return;
    final normalized = sanitizeImageBedBaseUrl(parsed).toString();
    if (normalized != raw) {
      _baseUrlController.text = normalized;
    }
    ref.read(imageBedSettingsProvider.notifier).setBaseUrl(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(imageBedSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);

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
        title: Text(context.tr(zh: '图床设置', en: 'Image Bed')),
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
                    colors: [
                      const Color(0xFF0B0B0B),
                      bg,
                      bg,
                    ],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _ToggleCard(
                card: card,
                textMain: textMain,
                textMuted: textMuted,
                label: context.tr(zh: '启用图床', en: 'Enable image bed'),
                description: context.tr(
                  zh: '开启后自动上传图片并在正文末尾插入链接。',
                  en: 'Automatically upload images and append links to the memo.',
                ),
                value: settings.enabled,
                onChanged: (value) => ref.read(imageBedSettingsProvider.notifier).setEnabled(value),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(zh: '服务商', en: 'Provider'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMuted),
              ),
              const SizedBox(height: 10),
              _Group(
                card: card,
                divider: divider,
                children: [
                  _SelectRow(
                    label: context.tr(zh: '兰空图床', en: 'Image Bed'),
                    value: _providerLabel(context, _provider),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: _selectProvider,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(zh: '基础配置', en: 'Basics'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMuted),
              ),
              const SizedBox(height: 10),
              _Group(
                card: card,
                divider: divider,
                children: [
                  _InputRow(
                    label: context.tr(zh: 'API 地址', en: 'API URL'),
                    hint: 'https://lsky.example.com',
                    controller: _baseUrlController,
                    textMain: textMain,
                    textMuted: textMuted,
                    keyboardType: TextInputType.url,
                    onChanged: (v) {
                      _markDirty();
                      ref.read(imageBedSettingsProvider.notifier).setBaseUrl(v);
                    },
                    onEditingComplete: _normalizeBaseUrl,
                  ),
                  _InputRow(
                    label: context.tr(zh: '邮箱', en: 'Email'),
                    hint: context.tr(zh: '请输入邮箱', en: 'Enter email'),
                    controller: _emailController,
                    textMain: textMain,
                    textMuted: textMuted,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (v) {
                      _markDirty();
                      ref.read(imageBedSettingsProvider.notifier).setEmail(v);
                    },
                  ),
                  _InputRow(
                    label: context.tr(zh: '密码', en: 'Password'),
                    hint: context.tr(zh: '请输入密码', en: 'Enter password'),
                    controller: _passwordController,
                    textMain: textMain,
                    textMuted: textMuted,
                    obscureText: true,
                    onChanged: (v) {
                      _markDirty();
                      ref.read(imageBedSettingsProvider.notifier).setPassword(v);
                    },
                  ),
                  _InputRow(
                    label: context.tr(zh: '策略 ID', en: 'Strategy ID'),
                    hint: context.tr(zh: '选填，使用默认存储策略时请留空', en: 'Optional. Leave empty for default.'),
                    controller: _strategyController,
                    textMain: textMain,
                    textMuted: textMuted,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      _markDirty();
                      ref.read(imageBedSettingsProvider.notifier).setStrategyId(v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(zh: '策略设置', en: 'Policy'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMuted),
              ),
              const SizedBox(height: 10),
              _Group(
                card: card,
                divider: divider,
                children: [
                  _StepperRow(
                    label: context.tr(zh: '失败重试次数', en: 'Retry Count'),
                    value: _retryCount,
                    textMain: textMain,
                    textMuted: textMuted,
                    onDecrease: () => _updateRetry(-1),
                    onIncrease: () => _updateRetry(1),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  zh: '重试次数决定了上传失败后的最大尝试频率。设置较高的次数可以提高成功率，但可能增加等待时间。',
                  en: 'Retry count controls how many extra attempts are made on failure. Higher values may improve success but take longer.',
                ),
                style: TextStyle(fontSize: 12, height: 1.35, color: textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.card,
    required this.divider,
    required this.children,
  });

  final Color card;
  final Color divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, color: divider),
          ],
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
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
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textMain)),
              ),
              Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.label,
    required this.hint,
    required this.controller,
    required this.textMain,
    required this.textMuted,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.onEditingComplete,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final Color textMain;
  final Color textMuted;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: textMuted),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final int value;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);
    final pillBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    Widget buildButton(IconData icon, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 16, color: textMuted),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textMain)),
          ),
          Container(
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: pillBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildButton(Icons.remove, onDecrease),
                const SizedBox(width: 6),
                Text('$value ${context.tr(zh: '次', en: 'times')}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
                const SizedBox(width: 6),
                buildButton(Icons.add, onIncrease),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
