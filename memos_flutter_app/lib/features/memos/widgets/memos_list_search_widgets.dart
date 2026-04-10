import 'package:flutter/material.dart';

import '../../../core/memoflow_palette.dart';
import '../../../core/tag_badge.dart';
import '../../../core/tag_colors.dart';
import '../../../i18n/strings.g.dart';
import '../../../state/memos/memos_providers.dart';
import '../../../state/tags/tag_color_lookup.dart';
import '../home_quick_actions.dart';

class MemosListPillRow extends StatelessWidget {
  const MemosListPillRow({super.key, required this.quickActions});

  final List<HomeQuickActionChipData> quickActions;

  @override
  Widget build(BuildContext context) {
    if (quickActions.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final bgColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < quickActions.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            MemosListPillButton(
              icon: quickActions[index].icon,
              iconColor: quickActions[index].iconColor,
              label: quickActions[index].label,
              onPressed: quickActions[index].onPressed,
              backgroundColor: bgColor,
              borderColor: borderColor,
              textColor: textColor,
            ),
          ],
        ],
      ),
    );
  }
}

class MemosListSearchLanding extends StatefulWidget {
  const MemosListSearchLanding({
    super.key,
    required this.history,
    required this.onClearHistory,
    required this.onRemoveHistory,
    required this.onSelectHistory,
    required this.tags,
    required this.tagColors,
    required this.onSelectTag,
  });

  final List<String> history;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onRemoveHistory;
  final ValueChanged<String> onSelectHistory;
  final List<String> tags;
  final TagColorLookup tagColors;
  final ValueChanged<String> onSelectTag;

  @override
  State<MemosListSearchLanding> createState() => _MemosListSearchLandingState();
}

class _MemosListSearchLandingState extends State<MemosListSearchLanding> {
  static const _collapsedTagCount = 6;
  static const _historyListMaxHeight = 220.0;

  final ScrollController _historyScrollController = ScrollController();
  bool _showAllTags = false;

  @override
  void dispose() {
    _historyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final tags = widget.tags;
    final hasMoreTags = tags.length > _collapsedTagCount;
    final visibleTags = _showAllTags || !hasMoreTags
        ? tags
        : tags.take(_collapsedTagCount).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.t.strings.legacy.msg_recent_searches,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (widget.history.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onClearHistory,
                  icon: Icon(Icons.delete_outline, size: 18, color: textMuted),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.t.strings.legacy.msg_no_search_history,
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: _historyListMaxHeight,
              ),
              child: Scrollbar(
                controller: _historyScrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _historyScrollController,
                  shrinkWrap: true,
                  primary: false,
                  padding: EdgeInsets.zero,
                  itemCount: widget.history.length,
                  itemBuilder: (context, index) {
                    final item = widget.history[index];
                    return InkWell(
                      onTap: () => widget.onSelectHistory(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.history, size: 18, color: textMuted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(fontSize: 14, color: textMain),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => widget.onRemoveHistory(item),
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                context.t.strings.legacy.msg_suggested_tags,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
              ),
              const Spacer(),
              if (hasMoreTags)
                TextButton.icon(
                  onPressed: () => setState(() => _showAllTags = !_showAllTags),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    _showAllTags ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: textMuted,
                  ),
                  label: Text(
                    _showAllTags
                        ? context.t.strings.legacy.msg_collapse
                        : context.t.strings.legacy.msg_show_all,
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (tags.isEmpty)
            Text(
              context.t.strings.legacy.msg_no_tags,
              style: TextStyle(fontSize: 12, color: textMuted),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final tag in visibleTags)
                  InkWell(
                    onTap: () => widget.onSelectTag('#${tag.trim()}'),
                    borderRadius: BorderRadius.circular(12),
                    child: TagBadge(
                      label: '#${tag.trim()}',
                      colors: widget.tagColors.resolveChipColorsByPath(
                        tag.trim(),
                        surfaceColor: Theme.of(context).colorScheme.surface,
                        isDark: isDark,
                      ),
                      compact: true,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              context.t.strings.legacy.msg_search_title_content_tags,
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class MemosListSearchQuickFilterBar extends StatelessWidget {
  const MemosListSearchQuickFilterBar({
    super.key,
    required this.selectedKind,
    required this.onSelectKind,
  });

  final QuickSearchKind? selectedKind;
  final ValueChanged<QuickSearchKind> onSelectKind;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.64);
    final accent = MemoFlowPalette.primary;
    final chipBg = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final selectedBg = accent.withValues(alpha: isDark ? 0.22 : 0.14);
    final selectedBorder = accent.withValues(alpha: isDark ? 0.58 : 0.48);
    final items = <({QuickSearchKind kind, IconData icon, String label})>[
      (
        kind: QuickSearchKind.attachments,
        icon: Icons.attachment_outlined,
        label: context.t.strings.legacy.msg_attachments,
      ),
      (
        kind: QuickSearchKind.links,
        icon: Icons.link_outlined,
        label: context.t.strings.legacy.msg_links_label,
      ),
      (
        kind: QuickSearchKind.voice,
        icon: Icons.keyboard_voice_outlined,
        label: context.t.strings.legacy.msg_voice_memos,
      ),
      (
        kind: QuickSearchKind.onThisDay,
        icon: Icons.history_edu_outlined,
        label: context.t.strings.legacy.msg_on_this_day,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            _buildQuickChip(
              item: items[index],
              selected: selectedKind == items[index].kind,
              textMuted: textMuted,
              accent: accent,
              chipBg: chipBg,
              border: border,
              selectedBg: selectedBg,
              selectedBorder: selectedBorder,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required ({QuickSearchKind kind, IconData icon, String label}) item,
    required bool selected,
    required Color textMuted,
    required Color accent,
    required Color chipBg,
    required Color border,
    required Color selectedBg,
    required Color selectedBorder,
  }) {
    final bg = selected ? selectedBg : chipBg;
    final chipBorder = selected ? selectedBorder : border;
    final textColor = selected ? accent : textMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onSelectKind(item.kind),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemosListTagFilterBar extends StatelessWidget {
  const MemosListTagFilterBar({
    super.key,
    required this.tags,
    required this.selectedTag,
    required this.onSelectTag,
    required this.tagColors,
  });

  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String?> onSelectTag;
  final TagColorLookup tagColors;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final accent = MemoFlowPalette.primary;
    final chipBg = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final selectedBg = accent.withValues(alpha: isDark ? 0.22 : 0.14);
    final selectedBorder = accent.withValues(alpha: isDark ? 0.55 : 0.6);
    final normalizedSelected = (selectedTag ?? '').trim();

    Widget buildChip(
      String label, {
      required bool selected,
      required VoidCallback onTap,
      String? tagPath,
    }) {
      final colors = tagPath == null
          ? null
          : tagColors.resolveChipColorsByPath(
              tagPath,
              surfaceColor: Theme.of(context).colorScheme.surface,
              isDark: isDark,
            );
      final bg = colors?.background ?? (selected ? selectedBg : chipBg);
      final chipBorder = colors == null
          ? (selected ? selectedBorder : border)
          : (selected ? accent : colors.border);
      final textColor = colors?.text ?? (selected ? accent : textMuted);
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: chipBorder),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
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
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.strings.legacy.msg_filter_tags,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textMain,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              buildChip(
                context.t.strings.legacy.msg_all_2,
                selected: normalizedSelected.isEmpty,
                onTap: () => onSelectTag(null),
              ),
              for (final tag in tags)
                buildChip(
                  '#${tag.trim()}',
                  selected: normalizedSelected == tag.trim(),
                  onTap: () => onSelectTag(tag),
                  tagPath: tag.trim(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class MemosListFilterTagChip extends StatelessWidget {
  const MemosListFilterTagChip({
    super.key,
    required this.label,
    this.onClear,
    this.colors,
  });

  final String label;
  final VoidCallback? onClear;
  final TagChipColors? colors;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = MemoFlowPalette.primary;
    final bg =
        colors?.background ?? accent.withValues(alpha: isDark ? 0.22 : 0.14);
    final border =
        colors?.border ?? accent.withValues(alpha: isDark ? 0.55 : 0.6);
    final textColor = colors?.text ?? accent;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.close, size: 14, color: textColor),
          ],
        ],
      ),
    );

    if (onClear == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClear,
        borderRadius: BorderRadius.circular(999),
        child: chip,
      ),
    );
  }
}

class MemosListPillButton extends StatelessWidget {
  const MemosListPillButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.2
                  : 0.05,
            ),
          ),
        ],
      ),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: iconColor),
        label: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const StadiumBorder(),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
