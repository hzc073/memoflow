import 'package:flutter/material.dart';

import '../data/models/attachment.dart';
import 'memoflow_palette.dart';

const int _maxAttachmentToastLines = 3;
const double _toastHorizontalPadding = 14;
const double _toastVerticalPadding = 8;
const double _toastLineSpacing = 2;
const double _toastMargin = 12;
const double _toastGap = 6;

List<Attachment> filterNonMediaAttachments(List<Attachment> attachments) {
  if (attachments.isEmpty) return const [];
  return attachments
      .where((attachment) {
        final type = attachment.type.trim().toLowerCase();
        return !type.startsWith('image') && !type.startsWith('audio');
      })
      .toList(growable: false);
}

List<String> attachmentNameLines(
  List<Attachment> attachments, {
  int maxLines = _maxAttachmentToastLines,
}) {
  if (attachments.isEmpty) return const [];
  final names = <String>[];
  for (final attachment in attachments) {
    final label = _attachmentDisplayName(attachment);
    if (label.isNotEmpty) names.add(label);
  }
  if (names.isEmpty) return const [];
  final limit = maxLines.clamp(1, names.length);
  final lines = names.take(limit).toList(growable: true);
  final remaining = names.length - lines.length;
  if (remaining > 0) lines.add('+$remaining');
  return lines;
}

String _attachmentDisplayName(Attachment attachment) {
  final filename = attachment.filename.trim();
  if (filename.isNotEmpty) return filename;
  final uid = attachment.uid.trim();
  if (uid.isNotEmpty) return uid;
  final name = attachment.name.trim();
  if (name.isNotEmpty) return name;
  return 'attachment';
}

void showAttachmentNamesToast(
  BuildContext context,
  List<String> lines, {
  Offset? anchor,
}) {
  if (lines.isEmpty) return;
  final overlay = Overlay.of(context, rootOverlay: true);
  if (overlay == null) return;

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final toastBg = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
  final toastText = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
  final textStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: toastText,
  );
  final textDirection = Directionality.of(context);
  final screenSize = MediaQuery.of(context).size;
  final padding = MediaQuery.of(context).padding;

  double maxTextWidth = 0;
  double lineHeight = 0;
  final textPainter = TextPainter(
    textDirection: textDirection,
    maxLines: 1,
    ellipsis: '…',
  );
  for (final line in lines) {
    textPainter.text = TextSpan(text: line, style: textStyle);
    textPainter.layout();
    if (textPainter.width > maxTextWidth) {
      maxTextWidth = textPainter.width;
    }
    if (textPainter.height > lineHeight) {
      lineHeight = textPainter.height;
    }
  }
  if (lineHeight == 0) lineHeight = textStyle.fontSize ?? 12;
  final contentHeight =
      lineHeight * lines.length + _toastLineSpacing * (lines.length - 1);
  final rawWidth = maxTextWidth + _toastHorizontalPadding * 2;
  final rawHeight = contentHeight + _toastVerticalPadding * 2;
  final maxWidth =
      screenSize.width - padding.left - padding.right - _toastMargin * 2;
  final toastWidth = rawWidth.clamp(0.0, maxWidth);
  final toastHeight = rawHeight;

  Offset? anchorPoint = anchor;
  if (anchorPoint == null) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final offset = box.localToGlobal(Offset.zero);
      anchorPoint = Offset(offset.dx, offset.dy + box.size.height);
    }
  }

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      Widget toastBody() {
        return Material(
          color: Colors.transparent,
          child: Container(
            width: toastWidth,
            padding: const EdgeInsets.symmetric(
              horizontal: _toastHorizontalPadding,
              vertical: _toastVerticalPadding,
            ),
            decoration: BoxDecoration(
              color: toastBg,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: _toastLineSpacing),
                  Text(
                    lines[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ],
              ],
            ),
          ),
        );
      }

      if (anchorPoint == null) {
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: toastBody(),
            ),
          ),
        );
      }

      final minLeft = padding.left + _toastMargin;
      final maxLeft =
          screenSize.width - padding.right - _toastMargin - toastWidth;
      var left = anchorPoint!.dx;
      if (left > maxLeft) left = maxLeft;
      if (left < minLeft) left = minLeft;

      final minTop = padding.top + _toastMargin;
      final maxTop =
          screenSize.height - padding.bottom - _toastMargin - toastHeight;
      var top = anchorPoint!.dy + _toastGap;
      if (top > maxTop) {
        top = anchorPoint!.dy - _toastGap - toastHeight;
      }
      if (top < minTop) top = minTop;

      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: toastBody(),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 1400), () {
    if (entry.mounted) {
      entry.remove();
    }
  });
}
