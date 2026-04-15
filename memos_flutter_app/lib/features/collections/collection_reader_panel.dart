import 'package:flutter/material.dart';

import 'collection_reader_tokens.dart';

class CollectionReaderSheetFrame extends StatelessWidget {
  const CollectionReaderSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = CollectionReaderTokens.sheetPadding,
    this.expandChild = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: padding.copyWith(
          bottom: padding.bottom + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: expandChild ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CollectionReaderSheetHandle(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            if (expandChild) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

class CollectionReaderSheetHandle extends StatelessWidget {
  const CollectionReaderSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class CollectionReaderSectionTitle extends StatelessWidget {
  const CollectionReaderSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class CollectionReaderPanelCard extends StatelessWidget {
  const CollectionReaderPanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.34 : 0.52,
        ),
        borderRadius: BorderRadius.circular(CollectionReaderTokens.cardRadius),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.16 : 0.12),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class CollectionReaderHorizontalScroller extends StatelessWidget {
  const CollectionReaderHorizontalScroller({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: child,
      ),
    );
  }
}

class CollectionReaderLabeledSlider extends StatelessWidget {
  const CollectionReaderLabeledSlider({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(valueText, style: theme.textTheme.bodySmall),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2.8,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
