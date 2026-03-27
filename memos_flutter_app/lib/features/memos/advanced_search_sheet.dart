import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/memoflow_palette.dart';
import '../../i18n/strings.g.dart';
import '../../state/memos/memos_providers.dart';

class AdvancedSearchSheet extends StatefulWidget {
  const AdvancedSearchSheet({
    super.key,
    required this.initial,
    required this.showCreatedDateFilter,
    this.onApply,
    this.onCancel,
  });

  final AdvancedSearchFilters initial;
  final bool showCreatedDateFilter;
  final ValueChanged<AdvancedSearchFilters>? onApply;
  final VoidCallback? onCancel;

  static Future<AdvancedSearchFilters?> show(
    BuildContext context, {
    required AdvancedSearchFilters initial,
    required bool showCreatedDateFilter,
  }) {
    return showModalBottomSheet<AdvancedSearchFilters>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AdvancedSearchSheet(
        initial: initial,
        showCreatedDateFilter: showCreatedDateFilter,
      ),
    );
  }

  @override
  State<AdvancedSearchSheet> createState() => _AdvancedSearchSheetState();
}

class _AdvancedSearchSheetState extends State<AdvancedSearchSheet> {
  late AdvancedSearchFilters _draft = widget.initial.normalized();
  late final TextEditingController _locationController = TextEditingController(
    text: _draft.locationContains,
  );
  late final TextEditingController _attachmentNameController =
      TextEditingController(text: _draft.attachmentNameContains);

  @override
  void dispose() {
    _locationController.dispose();
    _attachmentNameController.dispose();
    super.dispose();
  }

  Future<void> _openDateRangePicker() async {
    final now = DateTime.now();
    final initialRange =
        _draft.createdDateRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: MemoFlowPalette.primary),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (result == null) return;
    setState(() {
      _draft = _draft.copyWith(createdDateRange: result).normalized();
    });
  }

  void _setHasLocation(SearchToggleFilter value) {
    setState(() {
      _draft = _draft.copyWith(hasLocation: value).normalized();
      if (_draft.hasLocation == SearchToggleFilter.no) {
        _locationController.clear();
      }
    });
  }

  void _setLocationContains(String value) {
    setState(() {
      _draft = _draft
          .copyWith(
            locationContains: value,
            hasLocation: value.trim().isNotEmpty
                ? SearchToggleFilter.yes
                : _draft.hasLocation,
          )
          .normalized();
    });
  }

  void _setHasAttachments(SearchToggleFilter value) {
    setState(() {
      final clearAttachmentName = value == SearchToggleFilter.no;
      final clearAttachmentType = value != SearchToggleFilter.yes;
      _draft = _draft
          .copyWith(
            hasAttachments: value,
            attachmentNameContains: clearAttachmentName
                ? ''
                : _draft.attachmentNameContains,
            attachmentType: clearAttachmentType ? null : _draft.attachmentType,
          )
          .normalized();
      if (clearAttachmentName) {
        _attachmentNameController.clear();
      }
    });
  }

  void _setAttachmentNameContains(String value) {
    setState(() {
      _draft = _draft
          .copyWith(
            attachmentNameContains: value,
            hasAttachments: value.trim().isNotEmpty
                ? SearchToggleFilter.yes
                : _draft.hasAttachments,
          )
          .normalized();
    });
  }

  void _setAttachmentType(AdvancedAttachmentType? value) {
    setState(() {
      _draft = _draft
          .copyWith(
            attachmentType: value,
            hasAttachments: value != null
                ? SearchToggleFilter.yes
                : _draft.hasAttachments,
          )
          .normalized();
    });
  }

  void _setHasRelations(SearchToggleFilter value) {
    setState(() {
      _draft = _draft.copyWith(hasRelations: value).normalized();
    });
  }

  void _clearAll() {
    setState(() {
      _draft = AdvancedSearchFilters.empty;
      _locationController.clear();
      _attachmentNameController.clear();
    });
  }

  void _cancel() {
    if (widget.onCancel != null) {
      widget.onCancel!.call();
      return;
    }
    Navigator.of(context).pop();
  }

  void _apply() {
    final normalized = _draft.normalized();
    if (widget.onApply != null) {
      widget.onApply!(normalized);
      return;
    }
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.66);
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final dateFormat = DateFormat('yyyy-MM-dd');
    final insets = MediaQuery.viewInsetsOf(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  context.t.strings.legacy.msg_advanced_search,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showCreatedDateFilter) ...[
                        _SectionTitle(
                          label: context.t.strings.legacy.msg_date_range_2,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const ValueKey('advanced-search-date-range'),
                          onPressed: _openDateRangePicker,
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            _draft.createdDateRange == null
                                ? context.t.strings.legacy.msg_select_date_range
                                : '${dateFormat.format(_draft.createdDateRange!.start)} - ${dateFormat.format(_draft.createdDateRange!.end)}',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MemoFlowPalette.primary,
                            side: BorderSide(color: border),
                            shape: const StadiumBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _draft.createdDateRange == null
                                ? null
                                : () => setState(() {
                                    _draft = _draft
                                        .copyWith(createdDateRange: null)
                                        .normalized();
                                  }),
                            child: Text(context.t.strings.legacy.msg_clear),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      _SectionTitle(
                        label: context.t.strings.legacy.msg_location_2,
                      ),
                      const SizedBox(height: 8),
                      _SegmentedControl<SearchToggleFilter>(
                        keyPrefix: 'advanced-search-location',
                        value: _draft.hasLocation,
                        onChanged: _setHasLocation,
                        options: [
                          _SegmentOption(
                            value: SearchToggleFilter.any,
                            label: context.t.strings.legacy.msg_any,
                          ),
                          _SegmentOption(
                            value: SearchToggleFilter.yes,
                            label: context.t.strings.legacy.msg_yes,
                          ),
                          _SegmentOption(
                            value: SearchToggleFilter.no,
                            label: context.t.strings.legacy.msg_no,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _LabeledTextField(
                        fieldKey: const ValueKey(
                          'advanced-search-location-contains',
                        ),
                        label: context.t.strings.legacy.msg_location_contains,
                        controller: _locationController,
                        onChanged: _setLocationContains,
                        enabled: _draft.hasLocation != SearchToggleFilter.no,
                        card: card,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                      ),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        label: context.t.strings.legacy.msg_attachments,
                      ),
                      const SizedBox(height: 8),
                      _SegmentedControl<SearchToggleFilter>(
                        keyPrefix: 'advanced-search-attachments',
                        value: _draft.hasAttachments,
                        onChanged: _setHasAttachments,
                        options: [
                          _SegmentOption(
                            value: SearchToggleFilter.any,
                            label: context.t.strings.legacy.msg_any,
                          ),
                          _SegmentOption(
                            value: SearchToggleFilter.yes,
                            label: context.t.strings.legacy.msg_yes,
                          ),
                          _SegmentOption(
                            value: SearchToggleFilter.no,
                            label: context.t.strings.legacy.msg_no,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _LabeledTextField(
                        fieldKey: const ValueKey(
                          'advanced-search-attachment-name',
                        ),
                        label: context
                            .t
                            .strings
                            .legacy
                            .msg_attachment_name_contains,
                        controller: _attachmentNameController,
                        onChanged: _setAttachmentNameContains,
                        enabled: _draft.hasAttachments != SearchToggleFilter.no,
                        card: card,
                        border: border,
                        textMain: textMain,
                        textMuted: textMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.t.strings.legacy.msg_attachment_type,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TypeChip(
                            chipKey: const ValueKey(
                              'advanced-search-type-image',
                            ),
                            label: context.t.strings.legacy.msg_image,
                            selected:
                                _draft.attachmentType ==
                                AdvancedAttachmentType.image,
                            enabled:
                                _draft.hasAttachments != SearchToggleFilter.no,
                            onTap: () => _setAttachmentType(
                              _draft.attachmentType ==
                                      AdvancedAttachmentType.image
                                  ? null
                                  : AdvancedAttachmentType.image,
                            ),
                          ),
                          _TypeChip(
                            chipKey: const ValueKey(
                              'advanced-search-type-audio',
                            ),
                            label: context.t.strings.legacy.msg_audio,
                            selected:
                                _draft.attachmentType ==
                                AdvancedAttachmentType.audio,
                            enabled:
                                _draft.hasAttachments != SearchToggleFilter.no,
                            onTap: () => _setAttachmentType(
                              _draft.attachmentType ==
                                      AdvancedAttachmentType.audio
                                  ? null
                                  : AdvancedAttachmentType.audio,
                            ),
                          ),
                          _TypeChip(
                            chipKey: const ValueKey(
                              'advanced-search-type-document',
                            ),
                            label: context.t.strings.legacy.msg_document,
                            selected:
                                _draft.attachmentType ==
                                AdvancedAttachmentType.document,
                            enabled:
                                _draft.hasAttachments != SearchToggleFilter.no,
                            onTap: () => _setAttachmentType(
                              _draft.attachmentType ==
                                      AdvancedAttachmentType.document
                                  ? null
                                  : AdvancedAttachmentType.document,
                            ),
                          ),
                          _TypeChip(
                            chipKey: const ValueKey(
                              'advanced-search-type-other',
                            ),
                            label: context.t.strings.legacy.msg_other,
                            selected:
                                _draft.attachmentType ==
                                AdvancedAttachmentType.other,
                            enabled:
                                _draft.hasAttachments != SearchToggleFilter.no,
                            onTap: () => _setAttachmentType(
                              _draft.attachmentType ==
                                      AdvancedAttachmentType.other
                                  ? null
                                  : AdvancedAttachmentType.other,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        label: context.t.strings.legacy.msg_linked_memos,
                      ),
                      const SizedBox(height: 8),
                      _SegmentedControl<SearchToggleFilter>(
                        keyPrefix: 'advanced-search-relations',
                        value: _draft.hasRelations,
                        onChanged: _setHasRelations,
                        options: [
                          _SegmentOption(
                            value: SearchToggleFilter.any,
                            label: context.t.strings.legacy.msg_any,
                          ),
                          _SegmentOption(
                            value: SearchToggleFilter.yes,
                            label: context.t.strings.legacy.msg_yes,
                          ),
                          _SegmentOption(
                            value: SearchToggleFilter.no,
                            label: context.t.strings.legacy.msg_no,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      TextButton(
                        key: const ValueKey('advanced-search-clear-all'),
                        onPressed: _clearAll,
                        child: Text(context.t.strings.legacy.msg_clear),
                      ),
                      const Spacer(),
                      TextButton(
                        key: const ValueKey('advanced-search-cancel'),
                        onPressed: _cancel,
                        child: Text(context.t.strings.legacy.msg_cancel_2),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const ValueKey('advanced-search-apply'),
                        onPressed: _apply,
                        child: Text(context.t.strings.legacy.msg_apply),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).brightness == Brightness.dark
            ? MemoFlowPalette.textDark
            : MemoFlowPalette.textLight,
      ),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.enabled,
    required this.card,
    required this.border,
    required this.textMain,
    required this.textMuted,
  });

  final String label;
  final Key fieldKey;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final Color card;
  final Color border;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              key: fieldKey,
              controller: controller,
              onChanged: onChanged,
              enabled: enabled,
              style: TextStyle(fontSize: 14, color: textMain),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: label,
                hintStyle: TextStyle(color: textMuted),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = MemoFlowPalette.primary;
    final bg = selected
        ? accent.withValues(alpha: isDark ? 0.25 : 0.12)
        : (isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight);
    final border = selected
        ? accent.withValues(alpha: isDark ? 0.55 : 0.4)
        : (isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight);
    final textColor = !enabled
        ? (isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight)
              .withValues(alpha: 0.4)
        : (selected
              ? accent
              : (isDark
                    ? MemoFlowPalette.textDark
                    : MemoFlowPalette.textLight));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: chipKey,
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
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
    this.keyPrefix,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<_SegmentOption<T>> options;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;

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
                key: ValueKey(
                  '${keyPrefix ?? 'seg'}-${option.value.toString().split('.').last}',
                ),
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(option.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: option.value == value
                        ? MemoFlowPalette.primary
                        : Colors.transparent,
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
