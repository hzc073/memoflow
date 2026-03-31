import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/app_localization.dart';
import '../../../core/location_launcher.dart';
import '../../../core/memoflow_palette.dart';
import '../../../data/models/compose_draft.dart';
import '../../../i18n/strings.g.dart';
import '../draft_box_media_entries.dart';
import '../memo_card_preview.dart';
import '../memo_location_line.dart';
import '../memo_markdown.dart';
import '../memo_media_grid.dart';

class DraftBoxMemoCard extends StatefulWidget {
  const DraftBoxMemoCard({
    super.key,
    required this.draft,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final ComposeDraftRecord draft;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<DraftBoxMemoCard> createState() => _DraftBoxMemoCardState();
}

class _DraftBoxMemoCardState extends State<DraftBoxMemoCard> {
  static final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

  var _expanded = false;

  @override
  void didUpdateWidget(covariant DraftBoxMemoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.uid != widget.draft.uid) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final cardColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final primaryColor = MemoFlowPalette.primary;
    final selectedTint = primaryColor.withValues(alpha: isDark ? 0.18 : 0.08);
    final cardSurface = widget.selected
        ? Color.alphaBlend(selectedTint, cardColor)
        : cardColor;
    final cardBorderColor = widget.selected
        ? primaryColor.withValues(alpha: isDark ? 0.5 : 0.35)
        : borderColor;
    final deleteColor = isDark
        ? const Color(0xFFFF7A7A)
        : const Color(0xFFE05656);
    final subduedText = textMain.withValues(alpha: isDark ? 0.4 : 0.5);
    final attachmentColor = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final previewBorder = borderColor.withValues(alpha: 0.65);
    final previewBg = isDark
        ? MemoFlowPalette.audioSurfaceDark.withValues(alpha: 0.6)
        : MemoFlowPalette.audioSurfaceLight;
    final snapshot = widget.draft.snapshot;
    final previewText = buildMemoCardPreviewText(
      snapshot.content,
      collapseReferences: false,
      language: context.appLanguage,
    );
    final preview = truncateMemoCardPreview(
      previewText,
      collapseLongContent: true,
    );
    final showToggle = preview.truncated;
    final showCollapsed = showToggle && !_expanded;
    final mediaEntries = buildDraftBoxMediaEntries(snapshot);
    final nonMediaAttachmentCount = countDraftNonMediaAttachments(snapshot);
    final visibilityPresentation = _resolveVisibilityPresentation(
      context,
      snapshot.visibility,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('draft-box-open-${widget.draft.uid}'),
        borderRadius: BorderRadius.circular(22),
        onTap: widget.onTap,
        child: Container(
          key: ValueKey<String>('draft-box-card-${widget.draft.uid}'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cardBorderColor),
            boxShadow: [
              BoxShadow(
                blurRadius: isDark ? 20 : 12,
                offset: const Offset(0, 4),
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.03),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 32),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (widget.selected)
                                _DraftBoxBadge(
                                  label: context.t.strings.legacy.msg_editing,
                                  foreground: primaryColor,
                                  background: primaryColor.withValues(
                                    alpha: isDark ? 0.18 : 0.12,
                                  ),
                                  borderColor: primaryColor.withValues(
                                    alpha: isDark ? 0.42 : 0.24,
                                  ),
                                ),
                              Text(
                                _dateFormatter.format(
                                  widget.draft.updatedTime.toLocal(),
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: subduedText,
                                ),
                              ),
                              _DraftBoxBadge(
                                label: visibilityPresentation.label,
                                foreground: visibilityPresentation.color,
                                background: visibilityPresentation.color
                                    .withValues(alpha: isDark ? 0.18 : 0.1),
                                borderColor: visibilityPresentation.color
                                    .withValues(alpha: isDark ? 0.35 : 0.18),
                              ),
                            ],
                          ),
                        ),
                        if (snapshot.location != null) ...[
                          const SizedBox(height: 2),
                          MemoLocationLine(
                            location: snapshot.location!,
                            textColor: subduedText,
                            onTap: () => openMemoLocation(
                              context,
                              snapshot.location!,
                              memoUid: widget.draft.uid,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey<String>(
                      'draft-box-delete-${widget.draft.uid}',
                    ),
                    tooltip: context.t.strings.legacy.msg_delete,
                    onPressed: widget.onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: deleteColor,
                    ),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (previewText.isEmpty)
                Text(
                  context.t.strings.legacy.msg_empty_draft,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: subduedText),
                )
              else
                MemoMarkdown(
                  cacheKey: 'draft-box-${widget.draft.uid}',
                  data: previewText,
                  maxLines: showCollapsed ? kMemoCardPreviewMaxLines : null,
                  textStyle: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: textMain),
                  blockSpacing: 4,
                  normalizeHeadings: true,
                  renderImages: false,
                ),
              if (showToggle) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _expanded
                          ? context.t.strings.legacy.msg_collapse
                          : context.t.strings.legacy.msg_expand,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MemoFlowPalette.primary,
                      ),
                    ),
                  ),
                ),
              ],
              if (mediaEntries.isNotEmpty) ...[
                const SizedBox(height: 6),
                KeyedSubtree(
                  key: ValueKey<String>('draft-box-media-${widget.draft.uid}'),
                  child: MemoMediaGrid(
                    entries: mediaEntries,
                    columns: 3,
                    maxCount: 9,
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                    preserveSquareTilesWhenHeightLimited: Platform.isWindows,
                    radius: 0,
                    spacing: 4,
                    borderColor: previewBorder,
                    backgroundColor: previewBg,
                    textColor: textMain,
                    enableDownload: true,
                  ),
                ),
              ],
              if (nonMediaAttachmentCount > 0) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attach_file, size: 14, color: attachmentColor),
                    const SizedBox(width: 4),
                    Text(
                      nonMediaAttachmentCount.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: attachmentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _DraftVisibilityPresentation _resolveVisibilityPresentation(
    BuildContext context,
    String raw,
  ) {
    switch (raw.trim().toUpperCase()) {
      case 'PUBLIC':
        return _DraftVisibilityPresentation(
          label: context.t.strings.legacy.msg_public,
          color: const Color(0xFF3B8C52),
        );
      case 'PROTECTED':
        return _DraftVisibilityPresentation(
          label: context.t.strings.legacy.msg_protected,
          color: const Color(0xFFB26A2B),
        );
      default:
        return _DraftVisibilityPresentation(
          label: context.t.strings.legacy.msg_private_2,
          color: const Color(0xFF7C7C7C),
        );
    }
  }
}

class _DraftVisibilityPresentation {
  const _DraftVisibilityPresentation({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
}

class _DraftBoxBadge extends StatelessWidget {
  const _DraftBoxBadge({
    required this.label,
    required this.foreground,
    required this.background,
    required this.borderColor,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
