import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/models/shortcut.dart';
import '../../state/memos_providers.dart';

class ShortcutEditorResult {
  const ShortcutEditorResult({required this.title, required this.filter});

  final String title;
  final String filter;
}

class ShortcutEditorScreen extends ConsumerStatefulWidget {
  const ShortcutEditorScreen({super.key, this.shortcut});

  final Shortcut? shortcut;

  @override
  ConsumerState<ShortcutEditorScreen> createState() => _ShortcutEditorScreenState();
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
    _titleController = TextEditingController(text: widget.shortcut?.title ?? '');
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
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _TagPickerSheet(
        tags: tags,
        initial: _selectedTags,
      ),
    );
    if (selected == null) return;
    setState(() {
      _selectedTags
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _openDateRangePicker() async {
    final now = DateTime.now();
    final initial = _createdRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: MemoFlowPalette.primary),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '请输入筛选名称', en: 'Please enter a name.'))),
      );
      return;
    }
    if (filter.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '请至少设置一个条件', en: 'Please add at least one condition.'))),
      );
      return;
    }
    context.safePop(ShortcutEditorResult(title: title, filter: filter));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final border = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final canSubmit = _titleController.text.trim().isNotEmpty && _buildFilter().isNotEmpty;
    final tags = ref.watch(tagStatsProvider).valueOrNull ?? const <TagStat>[];
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: TextButton(
          onPressed: () => context.safePop(),
          child: Text(
            context.tr(zh: '取消', en: 'Cancel'),
            style: const TextStyle(color: MemoFlowPalette.primary, fontWeight: FontWeight.w600),
          ),
        ),
        title: Text(
          widget.shortcut == null
              ? context.tr(zh: '新建快捷筛选', en: 'New Shortcut')
              : context.tr(zh: '编辑快捷筛选', en: 'Edit Shortcut'),
          style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: Text(
              context.tr(zh: '完成', en: 'Done'),
              style: TextStyle(
                color: canSubmit ? MemoFlowPalette.primary : textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              _FieldLabel(text: context.tr(zh: '筛选名称', en: 'Name'), textColor: textMain),
              const SizedBox(height: 8),
              _TextFieldCard(
                cardColor: card,
                borderColor: border,
                controller: _titleController,
                hintText: context.tr(zh: '输入名称', en: 'Shortcut name'),
                textColor: textMain,
              ),
              const SizedBox(height: 16),
              _FieldLabel(text: context.tr(zh: '匹配方式', en: 'Match'), textColor: textMain),
              const SizedBox(height: 8),
              _SegmentedControl<_MatchMode>(
                value: _matchAll ? _MatchMode.all : _MatchMode.any,
                onChanged: (value) => setState(() => _matchAll = value == _MatchMode.all),
                options: [
                  _SegmentOption(value: _MatchMode.all, label: context.tr(zh: '满足所有条件', en: 'Match all')),
                  _SegmentOption(value: _MatchMode.any, label: context.tr(zh: '满足任一条件', en: 'Match any')),
                ],
              ),
              const SizedBox(height: 16),
              if (_hasUnsupportedFilter)
                _WarningCard(
                  cardColor: card,
                  borderColor: border,
                  text: context.tr(
                    zh: '该快捷筛选包含高级条件，保存将覆盖这些条件。',
                    en: 'This shortcut includes advanced conditions. Saving will overwrite them.',
                  ),
                ),
              if (_hasUnsupportedFilter) const SizedBox(height: 12),
              _ShortcutConditionCard(
                title: context.tr(zh: '标签', en: 'Tags'),
                onClear: _selectedTags.isEmpty ? null : _clearTags,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SegmentedControl<_TagMatchMode>(
                      value: _tagMatchMode,
                      onChanged: (value) => setState(() => _tagMatchMode = value),
                      options: [
                        _SegmentOption(value: _TagMatchMode.any, label: context.tr(zh: '包含任一', en: 'Any')),
                        _SegmentOption(value: _TagMatchMode.all, label: context.tr(zh: '包含全部', en: 'All')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _openTagPicker(tags),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(context.tr(zh: '选择标签', en: 'Select tags')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MemoFlowPalette.primary,
                          side: BorderSide(color: border),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    if (_selectedTags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedTags
                            .map(
                              (tag) => InputChip(
                                label: Text('#$tag'),
                                onDeleted: () => setState(() => _selectedTags.remove(tag)),
                                backgroundColor: card,
                                deleteIconColor: textMuted,
                                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: textMain),
                                side: BorderSide(color: border.withValues(alpha: 0.8)),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ShortcutConditionCard(
                title: context.tr(zh: '创建时间', en: 'Created'),
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
                        _SegmentOption(value: _CreatedMode.range, label: context.tr(zh: '日期范围', en: 'Date range')),
                        _SegmentOption(value: _CreatedMode.lastDays, label: context.tr(zh: '过去天数', en: 'Past days')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_createdMode == _CreatedMode.range) ...[
                      Text(
                        context.tr(zh: '在时间范围内', en: 'Within range'),
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _openDateRangePicker,
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          _createdRange == null
                              ? context.tr(zh: '选择时间范围', en: 'Select date range')
                              : '${dateFormat.format(_createdRange!.start)} - ${dateFormat.format(_createdRange!.end)}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MemoFlowPalette.primary,
                          side: BorderSide(color: border),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ] else ...[
                      Text(
                        context.tr(zh: '过去多少天', en: 'How many days back'),
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _lastDaysController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  hintText: context.tr(zh: '输入天数', en: 'Enter days'),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  final parsed = int.tryParse(value);
                                  setState(() => _createdLastDays = (parsed != null && parsed > 0) ? parsed : null);
                                },
                                style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
                              ),
                            ),
                            Text(
                              context.tr(zh: '天', en: 'days'),
                              style: TextStyle(fontWeight: FontWeight.w600, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ShortcutConditionCard(
                title: context.tr(zh: '可见性', en: 'Visibility'),
                onClear: _visibilityMode == _VisibilityMode.all ? null : _clearVisibility,
                child: _SegmentedControl<_VisibilityMode>(
                  value: _visibilityMode,
                  onChanged: (value) => setState(() => _visibilityMode = value),
                  options: [
                    _SegmentOption(value: _VisibilityMode.private, label: context.tr(zh: '仅私密', en: 'Private')),
                    _SegmentOption(value: _VisibilityMode.public, label: context.tr(zh: '公开', en: 'Public')),
                    _SegmentOption(value: _VisibilityMode.all, label: context.tr(zh: '全部', en: 'All')),
                  ],
                ),
              ),
            ],
          ),
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
    final tags = _selectedTags.map(_escapeFilterValue).toList(growable: false)..sort();
    if (_tagMatchMode == _TagMatchMode.any || tags.length == 1) {
      return 'tag in [${tags.map(_quoteValue).join(', ')}]';
    }
    final parts = tags.map((tag) => 'tag in [${_quoteValue(tag)}]').toList(growable: false);
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
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
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
    return raw.replaceAll('\\', r'\\').replaceAll('"', r'\"').replaceAll('\n', ' ');
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

    final relativeSeconds = _extractTimestamp(filter, r'created_ts\s*(?:>=|>)\s*now\(\)\s*-\s*(\d+)');
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
      final startSec = _extractTimestamp(filter, r'created_ts\s*(?:>=|>)\s*(\d+)');
      final endSec = _extractTimestamp(filter, r'created_ts\s*(?:<=|<)\s*(\d+)');
      if (startSec != null && endSec != null) {
        final start = DateTime.fromMillisecondsSinceEpoch(startSec * 1000, isUtc: true).toLocal();
        final end = DateTime.fromMillisecondsSinceEpoch(endSec * 1000, isUtc: true).toLocal();
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
    if (unsupportedFields.any((field) => RegExp(r'\b$field\b').hasMatch(filter))) {
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
    final start = DateTime.fromMillisecondsSinceEpoch(startSec * 1000, isUtc: true).toLocal();
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
    final direct = RegExp(r'visibility\s*==\s*"(PUBLIC|PRIVATE|PROTECTED)"').firstMatch(filter);
    if (direct != null) {
      final value = direct.group(1);
      if (value == 'PUBLIC') return _VisibilityMode.public;
      if (value == 'PRIVATE') return _VisibilityMode.private;
      return null;
    }

    final listMatch = RegExp(r'visibility\s+in\s+\[([^\]]*)\]').firstMatch(filter);
    if (listMatch == null) return null;
    final values = _parseQuotedValues(listMatch.group(1) ?? '');
    final normalized = values.map((e) => e.toUpperCase()).toSet();
    if (normalized.length == 1 && normalized.contains('PUBLIC')) return _VisibilityMode.public;
    if (normalized.length == 1 && normalized.contains('PRIVATE')) return _VisibilityMode.private;
    return null;
  }

  List<String> _parseQuotedValues(String raw) {
    final matches = RegExp("\"((?:\\\\.|[^\"\\\\])*)\"|'((?:\\\\.|[^'\\\\])*)'").allMatches(raw);
    final out = <String>[];
    for (final match in matches) {
      final value = (match.group(1) ?? match.group(2) ?? '').trim();
      if (value.isEmpty) continue;
      out.add(_unescapeFilterValue(value));
    }
    return out;
  }

  String _unescapeFilterValue(String raw) {
    return raw.replaceAll(r'\\\"', '"').replaceAll(r"\\'", "'").replaceAll(r'\\\\', '\\');
  }
}

enum _MatchMode { all, any }

enum _TagMatchMode { any, all }

enum _CreatedMode { range, lastDays }

enum _VisibilityMode { private, public, all }

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, required this.textColor});

  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
    );
  }
}

class _TextFieldCard extends StatelessWidget {
  const _TextFieldCard({
    required this.cardColor,
    required this.borderColor,
    required this.controller,
    required this.hintText,
    required this.textColor,
  });

  final Color cardColor;
  final Color borderColor;
  final TextEditingController controller;
  final String hintText;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          isDense: true,
        ),
        style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.cardColor,
    required this.borderColor,
    required this.text,
  });

  final Color cardColor;
  final Color borderColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: textMain.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: textMain.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final border = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
              ),
              const Spacer(),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: Icon(Icons.close, size: 18, color: textMain.withValues(alpha: 0.6)),
                  tooltip: context.tr(zh: '清空', en: 'Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(option.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: option.value == value ? MemoFlowPalette.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: option.value == value ? Colors.white : textMain,
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
  const _TagPickerSheet({
    required this.tags,
    required this.initial,
  });

  final List<TagStat> tags;
  final Set<String> initial;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: 0.55);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => context.safePop(),
                  child: Text(
                    context.tr(zh: '取消', en: 'Cancel'),
                    style: const TextStyle(color: MemoFlowPalette.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text(
                  context.tr(zh: '选择标签', en: 'Select tags'),
                  style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.safePop(_selected),
                  child: Text(
                    context.tr(zh: '完成', en: 'Done'),
                    style: const TextStyle(color: MemoFlowPalette.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: widget.tags.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.tr(zh: '暂无标签', en: 'No tags'),
                      style: TextStyle(color: textMuted),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.tags.length,
                    itemBuilder: (context, index) {
                      final tag = widget.tags[index];
                      final selected = _selected.contains(tag.tag);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(tag.tag);
                            } else {
                              _selected.remove(tag.tag);
                            }
                          });
                        },
                        title: Text('#${tag.tag}', style: TextStyle(color: textMain, fontWeight: FontWeight.w600)),
                        subtitle: Text('${tag.count}', style: TextStyle(fontSize: 12, color: textMuted)),
                        activeColor: MemoFlowPalette.primary,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
