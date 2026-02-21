import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../core/uid.dart';
import '../../data/models/memo_template_settings.dart';
import '../../state/memo_template_settings_provider.dart';

class TemplateSettingsScreen extends ConsumerWidget {
  const TemplateSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(memoTemplateSettingsProvider);
    final controller = ref.read(memoTemplateSettingsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    Future<void> openTemplateEditor({MemoTemplate? initial}) async {
      final edited = await showDialog<MemoTemplate>(
        context: context,
        builder: (_) => _TemplateEditorDialog(initial: initial),
      );
      if (edited == null) return;
      controller.upsertTemplate(edited);
    }

    Future<void> openVariableSettings() async {
      final updated = await showDialog<MemoTemplateVariableSettings>(
        context: context,
        builder: (_) =>
            _TemplateVariableSettingsDialog(initial: settings.variables),
      );
      if (updated == null) return;
      controller.setVariables(updated);
    }

    Future<void> openVariableDocsDialog() async {
      await showDialog<void>(
        context: context,
        builder: (_) =>
            _VariableDocsDialog(textMain: textMain, textMuted: textMuted),
      );
    }

    Future<void> deleteTemplate(MemoTemplate template) async {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('删除模板'),
              content: Text('确定删除“${template.name}”吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('删除'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      controller.removeTemplateById(template.id);
    }

    Widget buildTemplateCard(MemoTemplate template) {
      final subtitle = template.content.trim().isEmpty
          ? '空内容'
          : template.content.trim().replaceAll('\n', ' ');
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: ListTile(
          title: Text(
            template.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: '编辑',
                onPressed: () => openTemplateEditor(initial: template),
                icon: Icon(Icons.edit_outlined, color: textMuted),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: () => deleteTemplate(template),
                icon: Icon(Icons.delete_outline, color: textMuted),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildTemplateList(List<MemoTemplate> templates) {
      if (templates.isEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '暂无模板，点击“新增模板”创建。',
            style: TextStyle(fontSize: 13, color: textMuted),
          ),
        );
      }

      final maxHeight = (MediaQuery.sizeOf(context).height * 0.42)
          .clamp(220.0, 420.0)
          .toDouble();
      final estimatedHeight = (templates.length * 96.0)
          .clamp(96.0, maxHeight)
          .toDouble();

      return SizedBox(
        height: estimatedHeight,
        child: Scrollbar(
          thumbVisibility: templates.length > 3,
          child: ListView.builder(
            primary: false,
            padding: EdgeInsets.zero,
            itemCount: templates.length,
            itemBuilder: (_, index) => buildTemplateCard(templates[index]),
          ),
        ),
      );
    }

    final templates = settings.templates;
    final weatherSummary = settings.variables.weatherEnabled
        ? (settings.variables.weatherCity.trim().isEmpty
              ? '天气变量已启用（未设置城市）'
              : '天气变量：${settings.variables.weatherCity}')
        : '天气变量已关闭';

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
        title: const Text('模板'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '启用模板功能',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '启用后可在编辑器工具栏选择模板，选择后将覆盖输入框内容。',
                        style: TextStyle(
                          fontSize: 12,
                          color: textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.enabled,
                  onChanged: controller.setEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '模板列表',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => openTemplateEditor(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('新增模板'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '模板较多时，此区域支持上下滑动查看。',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 10),
          buildTemplateList(templates),
          const SizedBox(height: 8),
          Text(
            '变量设置',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: card,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: openVariableSettings,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '模板变量',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            weatherSummary,
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: textMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: card,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: openVariableDocsDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '可用变量说明',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '点击后在中间弹出变量表格与含义说明。',
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.help_outline, color: textMuted),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: textMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VariableDocsDialog extends StatefulWidget {
  const _VariableDocsDialog({required this.textMain, required this.textMuted});

  final Color textMain;
  final Color textMuted;

  @override
  State<_VariableDocsDialog> createState() => _VariableDocsDialogState();
}

class _VariableDocsDialogState extends State<_VariableDocsDialog> {
  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;

  static const _docs = <_VariableDoc>[
    _VariableDoc(token: '{{date}}', meaning: '当前日期', example: '2026-02-21'),
    _VariableDoc(token: '{{time}}', meaning: '当前时间', example: '09:30'),
    _VariableDoc(
      token: '{{datetime}}',
      meaning: '当前日期时间',
      example: '2026-02-21 09:30',
    ),
    _VariableDoc(token: '{{weekday}}', meaning: '星期名称', example: '星期六'),
    _VariableDoc(
      token: '{{weather}}',
      meaning: '天气 + 温度（不含城市）',
      example: '晴 25℃',
    ),
    _VariableDoc(
      token: '{{weather.summary}}',
      meaning: '城市 + 天气 + 温度',
      example: '北京 晴 25℃',
    ),
    _VariableDoc(token: '{{weather.city}}', meaning: '天气城市', example: '北京'),
    _VariableDoc(
      token: '{{weather.province}}',
      meaning: '天气省份',
      example: '北京市',
    ),
    _VariableDoc(token: '{{weather.condition}}', meaning: '天气现象', example: '晴'),
    _VariableDoc(
      token: '{{weather.temperature}}',
      meaning: '温度（不带单位）',
      example: '25',
    ),
    _VariableDoc(
      token: '{{weather.humidity}}',
      meaning: '湿度（不带 %）',
      example: '65',
    ),
    _VariableDoc(
      token: '{{weather.wind_direction}}',
      meaning: '风向',
      example: '东北',
    ),
    _VariableDoc(token: '{{weather.wind_power}}', meaning: '风力', example: '3'),
    _VariableDoc(
      token: '{{weather.report_time}}',
      meaning: '天气上报时间',
      example: '2026-02-21 09:00:00',
    ),
    _VariableDoc(
      token: '{{weather.adcode}}',
      meaning: '行政区编码',
      example: '110000',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _verticalController = ScrollController();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textMain = widget.textMain;
    final textMuted = widget.textMuted;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final headerBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final tokenColor = isDark
        ? const Color(0xFFE0E7FF)
        : const Color(0xFF27438F);

    Widget cell({
      required String text,
      required bool isHeader,
      required double width,
      Color? color,
      bool rightBorder = true,
    }) {
      return Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isHeader ? headerBg : Colors.transparent,
          border: Border(
            right: rightBorder
                ? BorderSide(color: borderColor)
                : BorderSide.none,
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
            color: color ?? (isHeader ? textMain : textMuted),
            height: 1.35,
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text('可用变量说明'),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '日期/时间变量受“变量设置”中的格式影响；天气变量依赖高德天气配置。',
              style: TextStyle(fontSize: 12, color: textMuted, height: 1.35),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 420,
              child: Scrollbar(
                controller: _verticalController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalController,
                  child: Scrollbar(
                    controller: _horizontalController,
                    thumbVisibility: true,
                    notificationPredicate: (notification) =>
                        notification.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Table(
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          columnWidths: const <int, TableColumnWidth>{
                            0: FixedColumnWidth(240),
                            1: FixedColumnWidth(220),
                            2: FixedColumnWidth(220),
                          },
                          children: [
                            TableRow(
                              children: [
                                cell(text: '变量', isHeader: true, width: 240),
                                cell(text: '含义', isHeader: true, width: 220),
                                cell(
                                  text: '示例',
                                  isHeader: true,
                                  width: 220,
                                  rightBorder: false,
                                ),
                              ],
                            ),
                            ..._docs.map(
                              (item) => TableRow(
                                children: [
                                  cell(
                                    text: item.token,
                                    isHeader: false,
                                    width: 240,
                                    color: tokenColor,
                                  ),
                                  cell(
                                    text: item.meaning,
                                    isHeader: false,
                                    width: 220,
                                  ),
                                  cell(
                                    text: item.example,
                                    isHeader: false,
                                    width: 220,
                                    rightBorder: false,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('我知道了'),
        ),
      ],
    );
  }
}

class _VariableDoc {
  const _VariableDoc({
    required this.token,
    required this.meaning,
    required this.example,
  });

  final String token;
  final String meaning;
  final String example;
}

class _TemplateEditorDialog extends StatefulWidget {
  const _TemplateEditorDialog({this.initial});

  final MemoTemplate? initial;

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _contentController = TextEditingController(
      text: widget.initial?.content ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final content = _contentController.text;
    final existing = widget.initial;
    final next = MemoTemplate(
      id: existing?.id ?? generateUid(),
      name: name,
      content: content,
    );
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    return AlertDialog(
      title: Text(widget.initial == null ? '新增模板' : '编辑模板'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('模板名称', style: TextStyle(fontSize: 12, color: textMuted)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              maxLength: 32,
              decoration: const InputDecoration(
                hintText: '例如：晨间复盘',
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            Text('模板内容', style: TextStyle(fontSize: 12, color: textMuted)),
            const SizedBox(height: 6),
            TextField(
              controller: _contentController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '可使用变量，例如：{{date}} {{weather}}',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}

class _TemplateVariableSettingsDialog extends StatefulWidget {
  const _TemplateVariableSettingsDialog({required this.initial});

  final MemoTemplateVariableSettings initial;

  @override
  State<_TemplateVariableSettingsDialog> createState() =>
      _TemplateVariableSettingsDialogState();
}

class _TemplateVariableSettingsDialogState
    extends State<_TemplateVariableSettingsDialog> {
  late final TextEditingController _dateFormatController;
  late final TextEditingController _timeFormatController;
  late final TextEditingController _dateTimeFormatController;
  late final TextEditingController _weatherCityController;
  late final TextEditingController _weatherFallbackController;
  late bool _weatherEnabled;
  late bool _keepUnknownVariables;

  @override
  void initState() {
    super.initState();
    _dateFormatController = TextEditingController(
      text: widget.initial.dateFormat,
    );
    _timeFormatController = TextEditingController(
      text: widget.initial.timeFormat,
    );
    _dateTimeFormatController = TextEditingController(
      text: widget.initial.dateTimeFormat,
    );
    _weatherCityController = TextEditingController(
      text: widget.initial.weatherCity,
    );
    _weatherFallbackController = TextEditingController(
      text: widget.initial.weatherFallback,
    );
    _weatherEnabled = widget.initial.weatherEnabled;
    _keepUnknownVariables = widget.initial.keepUnknownVariables;
  }

  @override
  void dispose() {
    _dateFormatController.dispose();
    _timeFormatController.dispose();
    _dateTimeFormatController.dispose();
    _weatherCityController.dispose();
    _weatherFallbackController.dispose();
    super.dispose();
  }

  void _save() {
    final next = widget.initial.copyWith(
      dateFormat: _dateFormatController.text.trim().isEmpty
          ? MemoTemplateVariableSettings.defaults.dateFormat
          : _dateFormatController.text.trim(),
      timeFormat: _timeFormatController.text.trim().isEmpty
          ? MemoTemplateVariableSettings.defaults.timeFormat
          : _timeFormatController.text.trim(),
      dateTimeFormat: _dateTimeFormatController.text.trim().isEmpty
          ? MemoTemplateVariableSettings.defaults.dateTimeFormat
          : _dateTimeFormatController.text.trim(),
      weatherEnabled: _weatherEnabled,
      weatherCity: _weatherCityController.text.trim(),
      weatherFallback: _weatherFallbackController.text.trim().isEmpty
          ? MemoTemplateVariableSettings.defaults.weatherFallback
          : _weatherFallbackController.text.trim(),
      keepUnknownVariables: _keepUnknownVariables,
    );
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    return AlertDialog(
      title: const Text('模板变量设置'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('日期格式（{{date}}）', style: TextStyle(color: textMuted)),
              const SizedBox(height: 6),
              TextField(
                controller: _dateFormatController,
                decoration: const InputDecoration(hintText: 'yyyy-MM-dd'),
              ),
              const SizedBox(height: 10),
              Text('时间格式（{{time}}）', style: TextStyle(color: textMuted)),
              const SizedBox(height: 6),
              TextField(
                controller: _timeFormatController,
                decoration: const InputDecoration(hintText: 'HH:mm'),
              ),
              const SizedBox(height: 10),
              Text('日期时间格式（{{datetime}}）', style: TextStyle(color: textMuted)),
              const SizedBox(height: 6),
              TextField(
                controller: _dateTimeFormatController,
                decoration: const InputDecoration(hintText: 'yyyy-MM-dd HH:mm'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _weatherEnabled,
                title: const Text('启用天气变量'),
                subtitle: const Text('变量：{{weather}} / {{weather.*}}'),
                onChanged: (value) => setState(() => _weatherEnabled = value),
              ),
              if (_weatherEnabled) ...[
                Text('天气城市（adcode 或城市名）', style: TextStyle(color: textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _weatherCityController,
                  decoration: const InputDecoration(hintText: '例如：110000'),
                ),
                const SizedBox(height: 10),
                Text('天气变量兜底文本', style: TextStyle(color: textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _weatherFallbackController,
                  decoration: const InputDecoration(hintText: '--'),
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _keepUnknownVariables,
                title: const Text('未知变量保留原文'),
                subtitle: const Text('关闭后，未知变量会替换为空字符串'),
                onChanged: (value) =>
                    setState(() => _keepUnknownVariables = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
