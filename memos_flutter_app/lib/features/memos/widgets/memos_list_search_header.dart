import 'package:flutter/material.dart';

import '../../../core/memoflow_palette.dart';
import '../../../i18n/strings.g.dart';
import '../memos_list_header_controller.dart';
import 'memos_list_search_widgets.dart';

class MemosListSortMenuButton extends StatelessWidget {
  const MemosListSortMenuButton({
    super.key,
    required this.controller,
    required this.isDark,
  });

  final MemosListHeaderController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    return PopupMenuButton<MemosListSortOption>(
      tooltip: context.t.strings.legacy.msg_sort,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor.withValues(alpha: 0.7)),
      ),
      color: isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight,
      onSelected: controller.setSortOption,
      itemBuilder: (context) => [
        _buildSortMenuItem(context, MemosListSortOption.createAsc, textColor),
        _buildSortMenuItem(context, MemosListSortOption.createDesc, textColor),
        _buildSortMenuItem(context, MemosListSortOption.updateAsc, textColor),
        _buildSortMenuItem(context, MemosListSortOption.updateDesc, textColor),
      ],
      icon: const Icon(Icons.sort),
    );
  }

  PopupMenuItem<MemosListSortOption> _buildSortMenuItem(
    BuildContext context,
    MemosListSortOption option,
    Color textColor,
  ) {
    final selected = option == controller.sortOption;
    final label = controller.sortOptionLabel(context, option);
    return PopupMenuItem<MemosListSortOption>(
      value: option,
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: selected
                ? Icon(Icons.check, size: 16, color: MemoFlowPalette.primary)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? MemoFlowPalette.primary : textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class MemosListHeaderTitle extends StatelessWidget {
  const MemosListHeaderTitle({
    super.key,
    required this.title,
    required this.enableTitleMenu,
    required this.anchorKey,
    required this.onOpenTitleMenu,
    required this.maybeHaptic,
  });

  final String title;
  final bool enableTitleMenu;
  final GlobalKey anchorKey;
  final VoidCallback onOpenTitleMenu;
  final VoidCallback maybeHaptic;

  @override
  Widget build(BuildContext context) {
    if (enableTitleMenu) {
      return InkWell(
        key: anchorKey,
        onTap: () {
          maybeHaptic();
          onOpenTitleMenu();
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 18,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      );
    }
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class MemosListTopSearchField extends StatelessWidget {
  const MemosListTopSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.autofocus,
    required this.hasAdvancedFilters,
    required this.onOpenAdvancedFilters,
    required this.onSubmitted,
    this.hintText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final bool autofocus;
  final bool hasAdvancedFilters;
  final VoidCallback onOpenAdvancedFilters;
  final ValueChanged<String> onSubmitted;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final hasQuery = controller.text.trim().isNotEmpty;
    final suffixIconWidth = hasQuery ? 72.0 : 40.0;

    Widget buildSearchActionButton({
      required String tooltip,
      required VoidCallback onPressed,
      required Widget icon,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        splashRadius: 18,
        icon: icon,
      );
    }

    return Container(
      key: const ValueKey('search'),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? MemoFlowPalette.borderDark.withValues(alpha: 0.7)
              : MemoFlowPalette.borderLight,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText ?? context.t.strings.legacy.msg_search,
          border: InputBorder.none,
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIconConstraints: BoxConstraints(
            minWidth: suffixIconWidth,
            minHeight: 36,
          ),
          suffixIcon: SizedBox(
            width: suffixIconWidth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                buildSearchActionButton(
                  tooltip: context.t.strings.legacy.msg_advanced_search,
                  onPressed: onOpenAdvancedFilters,
                  icon: Icon(
                    Icons.filter_alt_outlined,
                    size: 18,
                    color: hasAdvancedFilters ? MemoFlowPalette.primary : null,
                  ),
                ),
                if (hasQuery)
                  buildSearchActionButton(
                    tooltip: context.t.strings.legacy.msg_clear,
                    onPressed: controller.clear,
                    icon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
          ),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }
}

class MemosListActiveAdvancedFilterSliver extends StatelessWidget {
  const MemosListActiveAdvancedFilterSliver({
    super.key,
    required this.chips,
    required this.onClearAll,
    required this.onRemoveSingle,
  });

  final List<MemosListAdvancedSearchChipData> chips;
  final VoidCallback onClearAll;
  final ValueChanged<MemosListAdvancedSearchChipKind> onRemoveSingle;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.62);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.t.strings.legacy.msg_advanced_search,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onClearAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.t.strings.legacy.msg_clear_all_filters,
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in chips)
                  MemosListFilterTagChip(
                    label: chip.label,
                    onClear: () => onRemoveSingle(chip.kind),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
