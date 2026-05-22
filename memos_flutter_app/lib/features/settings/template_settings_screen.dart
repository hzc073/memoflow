import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../core/memoflow_palette.dart';
import '../../core/uid.dart';
import '../../data/models/memo_template_settings.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/memo_template_settings_provider.dart';

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
              title: Text(context.t.strings.legacy.msg_delete_template),
              content: Text(
                context.t.strings.legacy.msg_delete_template_confirm_with_name(
                  name: template.name,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.t.strings.common.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.t.strings.legacy.msg_delete),
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
          ? context.t.strings.legacy.msg_empty_content
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
                tooltip: context.t.strings.legacy.msg_edit,
                onPressed: () => openTemplateEditor(initial: template),
                icon: Icon(Icons.edit_outlined, color: textMuted),
              ),
              IconButton(
                tooltip: context.t.strings.legacy.msg_delete,
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
            context.t.strings.legacy.msg_no_templates_click_add,
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
              ? context
                    .t
                    .strings
                    .legacy
                    .msg_weather_variables_enabled_city_not_set
              : context.t.strings.legacy.msg_weather_variables_city(
                  city: settings.variables.weatherCity,
                ))
        : context.t.strings.legacy.msg_weather_variables_disabled;

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
            tooltip: context.t.strings.common.back,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(context.t.strings.legacy.msg_template),
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
                        context.t.strings.legacy.msg_template_feature_title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t.strings.legacy.msg_template_feature_desc,
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
                context.t.strings.legacy.msg_template_list,
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
                label: Text(context.t.strings.legacy.msg_new_template),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.t.strings.legacy.msg_many_templates_support_scroll,
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 10),
          buildTemplateList(templates),
          const SizedBox(height: 8),
          Text(
            context.t.strings.legacy.msg_variable_settings,
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
                            context.t.strings.legacy.msg_template_variables,
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
                            context
                                .t
                                .strings
                                .legacy
                                .msg_available_variable_docs,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context
                                .t
                                .strings
                                .legacy
                                .msg_available_variable_docs_desc,
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

  List<_VariableDoc> _docs(BuildContext context) => <_VariableDoc>[
    _VariableDoc(
      token: '{{date}}',
      meaning: context.t.strings.legacy.msg_current_date,
      example: '2026-02-21',
    ),
    _VariableDoc(
      token: '{{time}}',
      meaning: context.t.strings.legacy.msg_current_time,
      example: '09:30',
    ),
    _VariableDoc(
      token: '{{datetime}}',
      meaning: context.t.strings.legacy.msg_current_datetime,
      example: '2026-02-21 09:30',
    ),
    _VariableDoc(
      token: '{{weekday}}',
      meaning: context.t.strings.legacy.msg_weekday_name,
      example: context.t.strings.legacy.msg_example_saturday,
    ),
    _VariableDoc(
      token: '{{weather}}',
      meaning:
          context.t.strings.legacy.msg_weather_plus_temperature_without_city,
      example: context.t.strings.legacy.msg_example_sunny_25c,
    ),
    _VariableDoc(
      token: '{{weather.summary}}',
      meaning: context.t.strings.legacy.msg_city_plus_weather_plus_temperature,
      example: context.t.strings.legacy.msg_example_beijing_sunny_25c,
    ),
    _VariableDoc(
      token: '{{weather.city}}',
      meaning: context.t.strings.legacy.msg_weather_city_label,
      example: context.t.strings.legacy.msg_example_beijing,
    ),
    _VariableDoc(
      token: '{{weather.province}}',
      meaning: context.t.strings.legacy.msg_weather_province,
      example: context.t.strings.legacy.msg_example_beijing_city,
    ),
    _VariableDoc(
      token: '{{weather.condition}}',
      meaning: context.t.strings.legacy.msg_weather_condition,
      example: context.t.strings.legacy.msg_example_sunny,
    ),
    _VariableDoc(
      token: '{{weather.temperature}}',
      meaning: context.t.strings.legacy.msg_temperature_without_unit,
      example: '25',
    ),
    _VariableDoc(
      token: '{{weather.humidity}}',
      meaning: context.t.strings.legacy.msg_humidity_without_percent,
      example: '65',
    ),
    _VariableDoc(
      token: '{{weather.wind_direction}}',
      meaning: context.t.strings.legacy.msg_wind_direction,
      example: context.t.strings.legacy.msg_example_northeast,
    ),
    _VariableDoc(
      token: '{{weather.wind_power}}',
      meaning: context.t.strings.legacy.msg_wind_power,
      example: '3',
    ),
    _VariableDoc(
      token: '{{weather.report_time}}',
      meaning: context.t.strings.legacy.msg_weather_report_time,
      example: '2026-02-21 09:00:00',
    ),
    _VariableDoc(
      token: '{{weather.adcode}}',
      meaning: context.t.strings.legacy.msg_adcode,
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
    final docs = _docs(context);

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
      title: Text(context.t.strings.legacy.msg_available_variable_docs),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t.strings.legacy.msg_date_time_weather_variable_desc,
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
                                cell(
                                  text: context.t.strings.legacy.msg_variable,
                                  isHeader: true,
                                  width: 240,
                                ),
                                cell(
                                  text: context.t.strings.legacy.msg_meaning,
                                  isHeader: true,
                                  width: 220,
                                ),
                                cell(
                                  text: context.t.strings.legacy.msg_example,
                                  isHeader: true,
                                  width: 220,
                                  rightBorder: false,
                                ),
                              ],
                            ),
                            ...docs.map(
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
          child: Text(context.t.strings.legacy.msg_got_it),
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
      title: Text(
        widget.initial == null
            ? context.t.strings.legacy.msg_new_template
            : context.t.strings.legacy.msg_edit_template,
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t.strings.legacy.msg_template_name,
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              maxLength: 32,
              decoration: InputDecoration(
                hintText: context.t.strings.legacy.msg_template_name_example,
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.t.strings.legacy.msg_template_content,
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _contentController,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: context.t.strings.legacy.msg_template_content_example,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(context.t.strings.common.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.t.strings.common.save),
        ),
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
      title: Text(context.t.strings.legacy.msg_template_variable_settings),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t.strings.legacy.msg_date_format_variable,
                style: TextStyle(color: textMuted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _dateFormatController,
                decoration: const InputDecoration(hintText: 'yyyy-MM-dd'),
              ),
              const SizedBox(height: 10),
              Text(
                context.t.strings.legacy.msg_time_format_variable,
                style: TextStyle(color: textMuted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _timeFormatController,
                decoration: const InputDecoration(hintText: 'HH:mm'),
              ),
              const SizedBox(height: 10),
              Text(
                context.t.strings.legacy.msg_datetime_format_variable,
                style: TextStyle(color: textMuted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _dateTimeFormatController,
                decoration: const InputDecoration(hintText: 'yyyy-MM-dd HH:mm'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _weatherEnabled,
                title: Text(
                  context.t.strings.legacy.msg_enable_weather_variables,
                ),
                subtitle: Text(
                  context.t.strings.legacy.msg_weather_variable_tokens,
                ),
                onChanged: (value) => setState(() => _weatherEnabled = value),
              ),
              if (_weatherEnabled) ...[
                Text(
                  context.t.strings.legacy.msg_weather_city_adcode_or_name,
                  style: TextStyle(color: textMuted),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _weatherCityController,
                  decoration: InputDecoration(
                    hintText: context.t.strings.legacy.msg_weather_city_example,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.t.strings.legacy.msg_weather_fallback_text,
                  style: TextStyle(color: textMuted),
                ),
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
                title: Text(
                  context.t.strings.legacy.msg_keep_unknown_variables_raw,
                ),
                subtitle: Text(
                  context.t.strings.legacy.msg_keep_unknown_variables_raw_desc,
                ),
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
          child: Text(context.t.strings.common.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.t.strings.common.save),
        ),
      ],
    );
  }
}
