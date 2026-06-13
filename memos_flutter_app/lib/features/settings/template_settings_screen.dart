import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/uid.dart';
import '../../data/models/memo_template_settings.dart';
import '../../i18n/strings.g.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform/widgets/platform_list_section.dart';
import '../../platform/widgets/platform_primary_action.dart';
import '../../state/settings/memo_template_settings_provider.dart';
import 'settings_ui.dart';

class TemplateSettingsScreen extends ConsumerWidget {
  const TemplateSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(memoTemplateSettingsProvider);
    final controller = ref.read(memoTemplateSettingsProvider.notifier);
    final tokens = settingsPageTokens(context);

    Future<void> openTemplateEditor({MemoTemplate? initial}) async {
      final edited = await showPlatformDialog<MemoTemplate>(
        context: context,
        builder: (_) => _TemplateEditorDialog(initial: initial),
      );
      if (edited == null) return;
      controller.upsertTemplate(edited);
    }

    Future<void> openVariableSettings() async {
      final updated = await showPlatformDialog<MemoTemplateVariableSettings>(
        context: context,
        builder: (_) =>
            _TemplateVariableSettingsDialog(initial: settings.variables),
      );
      if (updated == null) return;
      controller.setVariables(updated);
    }

    Future<void> openVariableDocsDialog() async {
      await showPlatformDialog<void>(
        context: context,
        builder: (_) => const _VariableDocsDialog(),
      );
    }

    Future<void> deleteTemplate(MemoTemplate template) async {
      final confirmed = await showSettingsConfirmationDialog(
        context: context,
        title: context.t.strings.legacy.msg_delete_template,
        message: context.t.strings.legacy.msg_delete_template_confirm_with_name(
          name: template.name,
        ),
        confirmLabel: context.t.strings.legacy.msg_delete,
        cancelLabel: context.t.strings.common.cancel,
        destructive: true,
      );
      if (!confirmed) return;
      controller.removeTemplateById(template.id);
    }

    Widget buildTemplateRow(MemoTemplate template) {
      final subtitle = template.content.trim().isEmpty
          ? context.t.strings.legacy.msg_empty_content
          : template.content.trim().replaceAll('\n', ' ');
      return PlatformListSectionRow(
        title: SettingsRowTitle(template.name),
        subtitle: SettingsRowDescription(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: context.t.strings.legacy.msg_edit,
              onPressed: () => openTemplateEditor(initial: template),
              icon: Icon(Icons.edit_outlined, color: tokens.textMuted),
            ),
            IconButton(
              tooltip: context.t.strings.legacy.msg_delete,
              onPressed: () => deleteTemplate(template),
              icon: Icon(Icons.delete_outline, color: tokens.textMuted),
            ),
          ],
        ),
        denseOnDesktop: false,
      );
    }

    Widget buildTemplateSection(List<MemoTemplate> templates) {
      if (templates.isEmpty) {
        return SettingsSection(
          header: Text(context.t.strings.legacy.msg_template_list),
          footer: Text(
            context.t.strings.legacy.msg_many_templates_support_scroll,
          ),
          children: [
            SettingsInfoRow(
              description: context.t.strings.legacy.msg_no_templates_click_add,
            ),
          ],
        );
      }

      final maxHeight = (MediaQuery.sizeOf(context).height * 0.42)
          .clamp(220.0, 420.0)
          .toDouble();
      final estimatedHeight = (templates.length * 96.0)
          .clamp(96.0, maxHeight)
          .toDouble();

      return SettingsSection(
        header: Text(context.t.strings.legacy.msg_template_list),
        footer: Text(
          context.t.strings.legacy.msg_many_templates_support_scroll,
        ),
        children: [
          SizedBox(
            height: estimatedHeight,
            child: Scrollbar(
              thumbVisibility: templates.length > 3,
              child: ListView.builder(
                primary: false,
                padding: EdgeInsets.zero,
                itemCount: templates.length,
                itemBuilder: (_, index) => buildTemplateRow(templates[index]),
              ),
            ),
          ),
        ],
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

    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_template),
      actions: [
        IconButton(
          tooltip: context.t.strings.legacy.msg_new_template,
          onPressed: () => openTemplateEditor(),
          icon: const Icon(Icons.add),
        ),
      ],
      children: [
        SettingsToggleCard(
          label: context.t.strings.legacy.msg_template_feature_title,
          description: context.t.strings.legacy.msg_template_feature_desc,
          value: settings.enabled,
          onChanged: controller.setEnabled,
        ),
        const SizedBox(height: 12),
        buildTemplateSection(templates),
        const SizedBox(height: 12),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_variable_settings),
          children: [
            SettingsNavigationRow(
              label: context.t.strings.legacy.msg_template_variables,
              description: weatherSummary,
              onTap: openVariableSettings,
            ),
            SettingsNavigationRow(
              label: context.t.strings.legacy.msg_available_variable_docs,
              description:
                  context.t.strings.legacy.msg_available_variable_docs_desc,
              leading: Icon(Icons.help_outline, color: tokens.textMuted),
              onTap: openVariableDocsDialog,
            ),
          ],
        ),
      ],
    );
  }
}

class _VariableDocsDialog extends StatefulWidget {
  const _VariableDocsDialog();

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
    final tokens = settingsPageTokens(context);
    final textMain = tokens.textMain;
    final textMuted = tokens.textMuted;
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
    final tableHeight = (MediaQuery.sizeOf(context).height * 0.52)
        .clamp(260.0, 420.0)
        .toDouble();

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

    return SettingsFormDialog(
      maxWidth: 800,
      title: Text(context.t.strings.legacy.msg_available_variable_docs),
      actions: [
        SettingsDialogAction(
          onPressed: () => Navigator.of(context).maybePop(),
          variant: PlatformPrimaryActionVariant.filled,
          label: Text(context.t.strings.legacy.msg_got_it),
        ),
      ],
      children: [
        Text(
          context.t.strings.legacy.msg_date_time_weather_variable_desc,
          style: TextStyle(fontSize: 12, color: textMuted, height: 1.35),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: tableHeight,
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
    return SettingsFormDialog(
      maxWidth: 520,
      title: Text(
        widget.initial == null
            ? context.t.strings.legacy.msg_new_template
            : context.t.strings.legacy.msg_edit_template,
      ),
      actions: [
        SettingsDialogAction(
          onPressed: () => Navigator.of(context).maybePop(),
          label: Text(context.t.strings.common.cancel),
        ),
        SettingsDialogAction(
          onPressed: _save,
          variant: PlatformPrimaryActionVariant.filled,
          label: Text(context.t.strings.common.save),
        ),
      ],
      children: [
        SettingsDialogTextField(
          label: context.t.strings.legacy.msg_template_name,
          controller: _nameController,
          hint: context.t.strings.legacy.msg_template_name_example,
          maxLength: 32,
        ),
        const SizedBox(height: 12),
        SettingsDialogTextField(
          label: context.t.strings.legacy.msg_template_content,
          controller: _contentController,
          hint: context.t.strings.legacy.msg_template_content_example,
          minLines: 4,
          maxLines: 8,
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
    return SettingsFormDialog(
      maxWidth: 560,
      title: Text(context.t.strings.legacy.msg_template_variable_settings),
      actions: [
        SettingsDialogAction(
          onPressed: () => Navigator.of(context).maybePop(),
          label: Text(context.t.strings.common.cancel),
        ),
        SettingsDialogAction(
          onPressed: _save,
          variant: PlatformPrimaryActionVariant.filled,
          label: Text(context.t.strings.common.save),
        ),
      ],
      children: [
        SettingsDialogTextField(
          label: context.t.strings.legacy.msg_date_format_variable,
          controller: _dateFormatController,
          hint: 'yyyy-MM-dd',
        ),
        const SizedBox(height: 12),
        SettingsDialogTextField(
          label: context.t.strings.legacy.msg_time_format_variable,
          controller: _timeFormatController,
          hint: 'HH:mm',
        ),
        const SizedBox(height: 12),
        SettingsDialogTextField(
          label: context.t.strings.legacy.msg_datetime_format_variable,
          controller: _dateTimeFormatController,
          hint: 'yyyy-MM-dd HH:mm',
        ),
        const SizedBox(height: 12),
        _DialogToggleRow(
          title: context.t.strings.legacy.msg_enable_weather_variables,
          subtitle: context.t.strings.legacy.msg_weather_variable_tokens,
          value: _weatherEnabled,
          onChanged: (value) => setState(() => _weatherEnabled = value),
        ),
        if (_weatherEnabled) ...[
          const SizedBox(height: 12),
          SettingsDialogTextField(
            label: context.t.strings.legacy.msg_weather_city_adcode_or_name,
            controller: _weatherCityController,
            hint: context.t.strings.legacy.msg_weather_city_example,
          ),
          const SizedBox(height: 12),
          SettingsDialogTextField(
            label: context.t.strings.legacy.msg_weather_fallback_text,
            controller: _weatherFallbackController,
            hint: '--',
          ),
        ],
        const SizedBox(height: 8),
        _DialogToggleRow(
          title: context.t.strings.legacy.msg_keep_unknown_variables_raw,
          subtitle:
              context.t.strings.legacy.msg_keep_unknown_variables_raw_desc,
          value: _keepUnknownVariables,
          onChanged: (value) => setState(() => _keepUnknownVariables = value),
        ),
      ],
    );
  }
}

class _DialogToggleRow extends StatelessWidget {
  const _DialogToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsToggleRow(
      label: title,
      description: subtitle,
      value: value,
      onChanged: onChanged,
      onTap: () => onChanged(!value),
    );
  }
}
