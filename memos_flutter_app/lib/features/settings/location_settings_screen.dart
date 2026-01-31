import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/models/location_settings.dart';
import '../../state/location_settings_provider.dart';

class LocationSettingsScreen extends ConsumerStatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  ConsumerState<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends ConsumerState<LocationSettingsScreen> {
  final _webKeyController = TextEditingController();
  final _securityKeyController = TextEditingController();
  ProviderSubscription<LocationSettings>? _settingsSubscription;
  var _dirty = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(locationSettingsProvider);
    _applySettings(settings);
    _settingsSubscription = ref.listenManual<LocationSettings>(locationSettingsProvider, (prev, next) {
      if (_dirty || !mounted) return;
      _applySettings(next);
    });
  }

  @override
  void dispose() {
    _settingsSubscription?.close();
    _webKeyController.dispose();
    _securityKeyController.dispose();
    super.dispose();
  }

  void _applySettings(LocationSettings settings) {
    _webKeyController.text = settings.amapWebKey;
    _securityKeyController.text = settings.amapSecurityKey;
    setState(() {});
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(locationSettingsProvider);
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
        title: Text(context.tr(zh: '定位设置', en: 'Location')),
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
                label: context.tr(zh: '启用定位', en: 'Enable memo location'),
                description: context.tr(
                  zh: '在笔记中显示定位信息，未配置密钥时将仅显示经纬度。',
                  en: 'Show location metadata on memos. If not configured, coordinates will be shown instead.',
                ),
                value: settings.enabled,
                onChanged: (value) => ref.read(locationSettingsProvider.notifier).setEnabled(value),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(zh: '高德 Web API', en: 'Amap Web API'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMuted),
              ),
              const SizedBox(height: 10),
              _Group(
                card: card,
                divider: divider,
                children: [
                  _InputRow(
                    label: context.tr(zh: 'Web API Key', en: 'Web API Key'),
                    hint: context.tr(zh: '请输入高德 Web API Key', en: 'Enter your Amap Web API Key'),
                    controller: _webKeyController,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (v) {
                      _markDirty();
                      ref.read(locationSettingsProvider.notifier).setAmapWebKey(v);
                    },
                  ),
                  _InputRow(
                    label: context.tr(zh: '安全密钥（sig）', en: 'Security Key (sig)'),
                    hint: context.tr(zh: '选填，用于签名请求', en: 'Optional. Used to sign requests.'),
                    controller: _securityKeyController,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (v) {
                      _markDirty();
                      ref.read(locationSettingsProvider.notifier).setAmapSecurityKey(v);
                    },
                  ),
                  _PrecisionRow(
                    label: context.tr(zh: '定位精度', en: 'Location precision'),
                    value: settings.precision,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (value) {
                      _markDirty();
                      ref.read(locationSettingsProvider.notifier).setPrecision(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  zh: '定位将使用系统权限获取经纬度，并通过高德 Web API 反向地理解析地址，可在上方选择显示精度。',
                  en: 'MemoFlow uses system location permission to get coordinates, then reverse geocodes via Amap Web API. You can choose the display precision above.',
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
              Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: textMain))),
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

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.label,
    required this.hint,
    required this.controller,
    required this.textMain,
    required this.textMuted,
    this.onChanged,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<String>? onChanged;

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

class _PrecisionRow extends StatelessWidget {
  const _PrecisionRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
  });

  final String label;
  final LocationPrecision value;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<LocationPrecision> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final options = <(LocationPrecision, String)>[
      (LocationPrecision.province, context.tr(zh: '省', en: 'Province')),
      (LocationPrecision.city, context.tr(zh: '市', en: 'City')),
      (LocationPrecision.district, context.tr(zh: '区', en: 'District')),
      (LocationPrecision.street, context.tr(zh: '街道', en: 'Street')),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (option) => _buildChip(
                    option.$1,
                    option.$2,
                    chipBg,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(LocationPrecision precision, String text, Color chipBg) {
    final selected = precision == value;
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => onChanged(precision),
      selectedColor: MemoFlowPalette.primary,
      backgroundColor: chipBg,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : textMain,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
