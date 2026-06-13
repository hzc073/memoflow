import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../core/top_toast.dart';
import '../../core/windows_adaptive_surface.dart';
import '../../data/models/shortcut.dart';
import '../../platform/platform_route.dart';
import '../../platform/widgets/platform_picker.dart';
import '../../platform/widgets/platform_primary_action.dart';
import '../../platform/widgets/platform_secondary_task_surface.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../../i18n/strings.g.dart';
import 'settings_ui.dart';

class ShortcutEditorResult {
  const ShortcutEditorResult({required this.title, required this.filter});

  final String title;
  final String filter;
}

Future<ShortcutEditorResult?> openShortcutEditor(
  BuildContext context, {
  Shortcut? shortcut,
}) {
  final useTaskSurface = shouldUsePlatformSecondaryTaskSurface(context);
  final editor = ShortcutEditorScreen(
    shortcut: shortcut,
    embeddedTaskSurface: useTaskSurface,
  );
  if (useTaskSurface) {
    return showPlatformSecondaryTaskSurface<ShortcutEditorResult>(
      context: context,
      size: PlatformSecondaryTaskSurfaceSize.standard,
      builder: (_) => editor,
    );
  }
  return Navigator.of(context).push<ShortcutEditorResult>(
    buildPlatformPageRoute<ShortcutEditorResult>(
      context: context,
      builder: (_) => editor,
    ),
  );
}

class ShortcutEditorScreen extends ConsumerStatefulWidget {
  const ShortcutEditorScreen({
    super.key,
    this.shortcut,
    this.embeddedTaskSurface = false,
  });

  final Shortcut? shortcut;
  final bool embeddedTaskSurface;

  @override
  ConsumerState<ShortcutEditorScreen> createState() =>
      _ShortcutEditorScreenState();
}

class _ShortcutEditorScreenState extends ConsumerState<ShortcutEditorScreen> {
  late final TextEditingController _titleController;
  bool _matchAll = true;
  _TagMatchMode _tagMatchMode = _TagMatchMode.any;
  final Set<String> _selectedTags = {};
  _CreatedMode _createdMode = _CreatedMode.range;
  int? _createdLastDays;
  DateTimeRange? _createdRange;
  _VisibilityMode _visibilityMode = _VisibilityMode.all;
  bool _hasUnsupportedFilter = false;
  late final TextEditingController _lastDaysController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.shortcut?.title ?? '',
    );
    _titleController.addListener(() => setState(() {}));
    _lastDaysController = TextEditingController();
    _applyExistingFilter(widget.shortcut?.filter ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lastDaysController.dispose();
    super.dispose();
  }

  Future<void> _openTagPicker(List<TagStat> tags) async {
    final selected = await _showTagPickerSurface(context, tags);
    if (selected == null) return;
    setState(() {
      _selectedTags
        ..clear()
        ..addAll(selected);
    });
  }

  Future<Set<String>?> _showTagPickerSurface(
    BuildContext context,
    List<TagStat> tags,
  ) {
    if (shouldUseWindowsAdaptiveSurface(context)) {
      return showWindowsAdaptiveSurface<Set<String>>(
        context: context,
        kind: WindowsAdaptiveSurfaceKind.largeDialog,
        maxWidth: 720,
        builder: (context) =>
            _TagPickerSheet(tags: tags, initial: _selectedTags),
      );
    }
    return showPlatformPicker<Set<String>>(
      context: context,
      desktopMaxWidth: 520,
      builder: (context) => _TagPickerSheet(tags: tags, initial: _selectedTags),
    );
  }

  Future<void> _openDateRangePicker() async {
    final now = DateTime.now();
    final initial =
        _createdRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (result == null) return;
    setState(() => _createdRange = result);
  }

  void _clearTags() {
    setState(() => _selectedTags.clear());
  }

  void _clearDateRange() {
    setState(() => _createdRange = null);
  }

  void _clearLastDays() {
    setState(() {
      _createdLastDays = null;
      _lastDaysController.clear();
    });
  }

  void _clearVisibility() {
    setState(() => _visibilityMode = _VisibilityMode.all);
  }

  void _submit() {
    final title = _titleController.text.trim();
    final filter = _buildFilter();
    if (title.isEmpty) {
      showTopToast(context, context.t.strings.legacy.msg_enter_name);
      return;
    }
    if (filter.isEmpty) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_add_least_one_condition,
      );
      return;
    }
    context.safePop(ShortcutEditorResult(title: title, filter: filter));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final colorScheme = Theme.of(context).colorScheme;
    final canSubmit =
        _titleController.text.trim().isNotEmpty && _buildFilter().isNotEmpty;
    final tags = ref.watch(tagStatsProvider).valueOrNull ?? const <TagStat>[];
    final tagColors = ref.watch(tagColorLookupProvider);
    final dateFormat = DateFormat('yyyy/MM/dd');
    final titleText = widget.shortcut == null
        ? context.t.strings.legacy.msg_shortcut_2
        : context.t.strings.legacy.msg_edit_shortcut;
    final tr = context.t.strings.legacy;

    final editorChildren = <Widget>[
      SettingsSection(
        children: [
          SettingsInlineTextFieldRow(
            label: tr.msg_name,
            controller: _titleController,
            hint: tr.msg_shortcut_name,
          ),
        ],
      ),
      const SizedBox(height: 14),
      SettingsSection(
        header: Text(tr.msg_match),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: _SegmentedControl<_MatchMode>(
              value: _matchAll ? _MatchMode.all : _MatchMode.any,
              onChanged: (value) =>
                  setState(() => _matchAll = value == _MatchMode.all),
              options: [
                _SegmentOption(value: _MatchMode.all, label: tr.msg_match_all),
                _SegmentOption(value: _MatchMode.any, label: tr.msg_match_any),
              ],
            ),
          ),
        ],
      ),
      if (_hasUnsupportedFilter) ...[
        const SizedBox(height: 14),
        SettingsSection(
          children: [
            SettingsWarningRow(
              message:
                  tr.msg_shortcut_includes_advanced_conditions_saving_overwrite,
            ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      _ShortcutConditionCard(
        title: tr.msg_tags,
        onClear: _selectedTags.isEmpty ? null : _clearTags,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SegmentedControl<_TagMatchMode>(
              value: _tagMatchMode,
              onChanged: (value) => setState(() => _tagMatchMode = value),
              options: [
                _SegmentOption(value: _TagMatchMode.any, label: tr.msg_any),
                _SegmentOption(value: _TagMatchMode.all, label: tr.msg_all),
              ],
            ),
            const SizedBox(height: 10),
            SettingsAction(
              onPressed: () => _openTagPicker(tags),
              icon: const Icon(Icons.add, size: 16),
              variant: PlatformPrimaryActionVariant.outlined,
              label: Text(tr.msg_select_tags),
            ),
            if (_selectedTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedTags
                    .map((tag) {
                      final colors = tagColors.resolveChipColorsByPath(
                        tag,
                        surfaceColor: colorScheme.surface,
                        isDark: tokens.isDark,
                      );
                      return SettingsRemovableChip(
                        label: '#$tag',
                        deleteTooltip: tr.msg_remove,
                        onDeleted: () =>
                            setState(() => _selectedTags.remove(tag)),
                        backgroundColor:
                            colors?.background ?? colorScheme.surface,
                        foregroundColor: colors?.text ?? tokens.textMain,
                        borderColor:
                            colors?.border ??
                            colorScheme.outlineVariant.withValues(alpha: 0.8),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      _ShortcutConditionCard(
        title: tr.msg_created_2,
        onClear: _createdMode == _CreatedMode.range
            ? (_createdRange == null ? null : _clearDateRange)
            : (_createdLastDays == null ? null : _clearLastDays),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SegmentedControl<_CreatedMode>(
              value: _createdMode,
              onChanged: (value) => setState(() => _createdMode = value),
              options: [
                _SegmentOption(
                  value: _CreatedMode.range,
                  label: tr.msg_date_range_2,
                ),
                _SegmentOption(
                  value: _CreatedMode.lastDays,
                  label: tr.msg_past_days,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_createdMode == _CreatedMode.range) ...[
              SettingsRowDescription(tr.msg_within_range),
              const SizedBox(height: 8),
              SettingsAction(
                onPressed: _openDateRangePicker,
                icon: const Icon(Icons.date_range, size: 18),
                variant: PlatformPrimaryActionVariant.outlined,
                label: Text(
                  _createdRange == null
                      ? tr.msg_select_date_range
                      : '${dateFormat.format(_createdRange!.start)} - ${dateFormat.format(_createdRange!.end)}',
                ),
              ),
            ] else ...[
              SettingsNumericInlineFieldRow(
                label: tr.msg_how_many_days_back,
                controller: _lastDaysController,
                hint: tr.msg_enter_days,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  setState(
                    () => _createdLastDays = (parsed != null && parsed > 0)
                        ? parsed
                        : null,
                  );
                },
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      _ShortcutConditionCard(
        title: tr.msg_visibility,
        onClear: _visibilityMode == _VisibilityMode.all
            ? null
            : _clearVisibility,
        child: _SegmentedControl<_VisibilityMode>(
          value: _visibilityMode,
          onChanged: (value) => setState(() => _visibilityMode = value),
          options: [
            _SegmentOption(
              value: _VisibilityMode.private,
              label: tr.msg_private,
            ),
            _SegmentOption(value: _VisibilityMode.public, label: tr.msg_public),
            _SegmentOption(value: _VisibilityMode.all, label: tr.msg_all_2),
          ],
        ),
      ),
    ];

    final embeddedBody = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: editorChildren,
    );

    if (!widget.embeddedTaskSurface) {
      return SettingsPage(
        title: Text(titleText),
        showBackButton: false,
        actions: [
          TextButton(
            onPressed: () => context.safePop(),
            child: Text(tr.msg_cancel_2),
          ),
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: Text(tr.msg_done),
          ),
        ],
        children: editorChildren,
      );
    }

    return PlatformSecondaryTaskFrame(
      title: Text(titleText),
      closeTooltip: tr.msg_cancel_2,
      onClose: () => context.safePop(),
      backgroundColor: tokens.background,
      actions: [
        TextButton(
          onPressed: canSubmit ? _submit : null,
          child: Text(
            tr.msg_done,
            style: TextStyle(
              color: canSubmit ? colorScheme.primary : tokens.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      body: Stack(
        children: [
          if (tokens.isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B0B0B),
                      tokens.background,
                      tokens.background,
                    ],
                  ),
                ),
              ),
            ),
          embeddedBody,
        ],
      ),
    );
  }

  String _buildFilter() {
    final conditions = <String>[];

    final tagCondition = _buildTagCondition();
    if (tagCondition != null) {
      conditions.add(tagCondition);
    }

    final createdCondition = _buildCreatedCondition();
    if (createdCondition != null) {
      conditions.add(createdCondition);
    }

    final visibilityCondition = _buildVisibilityCondition();
    if (visibilityCondition != null) {
      conditions.add(visibilityCondition);
    }

    if (conditions.isEmpty) return '';
    final op = _matchAll ? ' && ' : ' || ';
    return conditions.map(_wrapIfNeeded).join(op);
  }

  String? _buildTagCondition() {
    if (_selectedTags.isEmpty) return null;
    final tags = _selectedTags.map(_escapeFilterValue).toList(growable: false)
      ..sort();
    if (_tagMatchMode == _TagMatchMode.any || tags.length == 1) {
      return 'tag in [${tags.map(_quoteValue).join(', ')}]';
    }
    final parts = tags
        .map((tag) => 'tag in [${_quoteValue(tag)}]')
        .toList(growable: false);
    return parts.join(' && ');
  }

  String? _buildCreatedCondition() {
    if (_createdMode == _CreatedMode.lastDays) {
      final days = _createdLastDays;
      if (days == null || days <= 0) return null;
      final seconds = days * 86400;
      return 'created_ts >= now() - $seconds';
    }

    final range = _createdRange;
    if (range == null) return null;
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
    );
    final startSec = start.toUtc().millisecondsSinceEpoch ~/ 1000;
    final endSec = end.toUtc().millisecondsSinceEpoch ~/ 1000;
    return 'created_ts >= $startSec && created_ts <= $endSec';
  }

  String? _buildVisibilityCondition() {
    switch (_visibilityMode) {
      case _VisibilityMode.private:
        return 'visibility == "PRIVATE"';
      case _VisibilityMode.public:
        return 'visibility == "PUBLIC"';
      case _VisibilityMode.all:
        return null;
    }
  }

  String _wrapIfNeeded(String condition) {
    final trimmed = condition.trim();
    if (trimmed.contains(' && ') || trimmed.contains(' || ')) {
      return '($trimmed)';
    }
    return trimmed;
  }

  String _quoteValue(String value) => '"$value"';

  String _escapeFilterValue(String raw) {
    return raw
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', ' ');
  }

  void _applyExistingFilter(String raw) {
    final filter = raw.trim();
    if (filter.isEmpty) return;

    var hasUnknown = false;
    final hasAnd = filter.contains('&&');
    final hasOr = filter.contains('||');
    if (hasAnd && !hasOr) {
      _matchAll = true;
    } else if (hasOr && !hasAnd) {
      _matchAll = false;
    } else if (hasAnd && hasOr) {
      hasUnknown = true;
    }

    final tagMatches = RegExp(r'tag\s+in\s+\[([^\]]*)\]').allMatches(filter);
    final parsedTags = <String>[];
    var sawAnyList = false;
    var sawSingleList = false;
    for (final match in tagMatches) {
      final rawList = match.group(1) ?? '';
      final values = _parseQuotedValues(rawList);
      if (values.isEmpty) continue;
      parsedTags.addAll(values);
      if (values.length > 1) {
        sawAnyList = true;
      } else {
        sawSingleList = true;
      }
    }
    if (parsedTags.isNotEmpty) {
      _selectedTags.addAll(parsedTags);
      if (sawAnyList && !sawSingleList) {
        _tagMatchMode = _TagMatchMode.any;
      } else if (!sawAnyList && sawSingleList && tagMatches.length > 1) {
        _tagMatchMode = _TagMatchMode.all;
      }
    } else if (RegExp(r'\btag\b').hasMatch(filter)) {
      hasUnknown = true;
    }

    final relativeSeconds = _extractTimestamp(
      filter,
      r'created_ts\s*(?:>=|>)\s*now\(\)\s*-\s*(\d+)',
    );
    if (relativeSeconds != null) {
      final days = _secondsToDays(relativeSeconds);
      if (days != null) {
        _createdMode = _CreatedMode.lastDays;
        _createdLastDays = days;
        _lastDaysController.text = days.toString();
      } else {
        hasUnknown = true;
      }
    } else {
      final startSec = _extractTimestamp(
        filter,
        r'created_ts\s*(?:>=|>)\s*(\d+)',
      );
      final endSec = _extractTimestamp(
        filter,
        r'created_ts\s*(?:<=|<)\s*(\d+)',
      );
      if (startSec != null && endSec != null) {
        final start = DateTime.fromMillisecondsSinceEpoch(
          startSec * 1000,
          isUtc: true,
        ).toLocal();
        final end = DateTime.fromMillisecondsSinceEpoch(
          endSec * 1000,
          isUtc: true,
        ).toLocal();
        _createdRange = DateTimeRange(start: start, end: end);
        _createdMode = _CreatedMode.range;
        _createdLastDays = null;
        _lastDaysController.text = '';
      } else if (startSec != null && endSec == null) {
        final estimated = _estimateLastDays(startSec);
        if (estimated != null) {
          _createdMode = _CreatedMode.lastDays;
          _createdLastDays = estimated;
          _lastDaysController.text = estimated.toString();
        } else {
          hasUnknown = true;
        }
      } else if (startSec != null || endSec != null) {
        hasUnknown = true;
      }
    }

    final visibility = _parseVisibility(filter);
    if (visibility != null) {
      _visibilityMode = visibility;
    } else if (RegExp(r'\bvisibility\b').hasMatch(filter)) {
      hasUnknown = true;
    }

    final unsupportedFields = [
      'content',
      'has_task_list',
      'has_link',
      'has_code',
      'has_incomplete_tasks',
      'pinned',
      'updated_ts',
      'tags',
      'creator_id',
    ];
    if (unsupportedFields.any(
      (field) => RegExp(r'\b$field\b').hasMatch(filter),
    )) {
      hasUnknown = true;
    }

    _hasUnsupportedFilter = hasUnknown;
  }

  int? _extractTimestamp(String filter, String pattern) {
    final match = RegExp(pattern).firstMatch(filter);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  int? _estimateLastDays(int startSec) {
    final start = DateTime.fromMillisecondsSinceEpoch(
      startSec * 1000,
      isUtc: true,
    ).toLocal();
    final startDay = DateTime(start.year, start.month, start.day);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    if (startDay.isAfter(todayStart)) return null;
    final days = todayStart.difference(startDay).inDays + 1;
    if (days <= 0 || days > 3650) return null;
    return days;
  }

  int? _secondsToDays(int seconds) {
    if (seconds <= 0) return null;
    if (seconds % 86400 != 0) return null;
    final days = seconds ~/ 86400;
    if (days <= 0 || days > 3650) return null;
    return days;
  }

  _VisibilityMode? _parseVisibility(String filter) {
    final direct = RegExp(
      r'visibility\s*==\s*"(PUBLIC|PRIVATE|PROTECTED)"',
    ).firstMatch(filter);
    if (direct != null) {
      final value = direct.group(1);
      if (value == 'PUBLIC') return _VisibilityMode.public;
      if (value == 'PRIVATE') return _VisibilityMode.private;
      return null;
    }

    final listMatch = RegExp(
      r'visibility\s+in\s+\[([^\]]*)\]',
    ).firstMatch(filter);
    if (listMatch == null) return null;
    final values = _parseQuotedValues(listMatch.group(1) ?? '');
    final normalized = values.map((e) => e.toUpperCase()).toSet();
    if (normalized.length == 1 && normalized.contains('PUBLIC')) {
      return _VisibilityMode.public;
    }
    if (normalized.length == 1 && normalized.contains('PRIVATE')) {
      return _VisibilityMode.private;
    }
    return null;
  }

  List<String> _parseQuotedValues(String raw) {
    final matches = RegExp(
      "\"((?:\\\\.|[^\"\\\\])*)\"|'((?:\\\\.|[^'\\\\])*)'",
    ).allMatches(raw);
    final out = <String>[];
    for (final match in matches) {
      final value = (match.group(1) ?? match.group(2) ?? '').trim();
      if (value.isEmpty) continue;
      out.add(_unescapeFilterValue(value));
    }
    return out;
  }

  String _unescapeFilterValue(String raw) {
    return raw
        .replaceAll(r'\\\"', '"')
        .replaceAll(r"\\'", "'")
        .replaceAll(r'\\\\', '\\');
  }
}

enum _MatchMode { all, any }

enum _TagMatchMode { any, all }

enum _CreatedMode { range, lastDays }

enum _VisibilityMode { private, public, all }

class _ShortcutConditionCard extends StatelessWidget {
  const _ShortcutConditionCard({
    required this.title,
    required this.child,
    this.onClear,
  });

  final String title;
  final Widget child;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SettingsSection(
      header: Text(title),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onClear != null) ...[
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton(
                    onPressed: onClear,
                    icon: Icon(Icons.close, size: 18, color: tokens.textMuted),
                    tooltip: context.t.strings.legacy.msg_clear,
                  ),
                ),
                Divider(
                  height: 12,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ],
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentOption<T> {
  const _SegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _SegmentedControl<T> extends StatelessWidget {
  const _SegmentedControl({
    required this.value,
    required this.onChanged,
    required this.options,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<_SegmentOption<T>> options;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(option.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: option.value == value
                        ? colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: option.value == value
                          ? colorScheme.onPrimary
                          : tokens.textMain,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({required this.tags, required this.initial});

  final List<TagStat> tags;
  final Set<String> initial;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final tr = context.t.strings.legacy;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                SettingsDialogAction(
                  onPressed: () => context.safePop(),
                  label: Text(tr.msg_cancel_2),
                ),
                const Spacer(),
                Text(
                  tr.msg_select_tags,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.textMain,
                  ),
                ),
                const Spacer(),
                SettingsDialogAction(
                  onPressed: () => context.safePop(_selected),
                  variant: PlatformPrimaryActionVariant.filled,
                  label: Text(tr.msg_done),
                ),
              ],
            ),
          ),
          Flexible(
            child: widget.tags.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      tr.msg_no_tags,
                      style: TextStyle(color: tokens.textMuted),
                    ),
                  )
                : SingleChildScrollView(
                    child: SettingsSection(
                      children: [
                        SettingsMultiChoiceList<String>(
                          values: _selected,
                          options: [
                            for (final tag in widget.tags)
                              SettingsChoiceOption<String>(
                                value: tag.tag,
                                label: '#${tag.tag}',
                                description: '${tag.count}',
                              ),
                          ],
                          onChanged: (next) {
                            setState(() {
                              _selected
                                ..clear()
                                ..addAll(next);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
