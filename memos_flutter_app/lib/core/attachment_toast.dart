import 'package:flutter/material.dart';

import '../data/models/attachment.dart';
import 'memoflow_palette.dart';

const double _toastHorizontalPadding = 14;
const double _toastVerticalPadding = 8;
const double _toastLineSpacing = 2;
const double _toastMargin = 12;
const double _toastGap = 6;
const String _toastEllipsis = '...';
OverlayEntry? _activeAttachmentToast;

List<Attachment> filterNonMediaAttachments(List<Attachment> attachments) {
  if (attachments.isEmpty) return const [];
  return attachments
      .where((attachment) {
        final type = attachment.type.trim().toLowerCase();
        return !type.startsWith('image') &&
            !type.startsWith('audio') &&
            !type.startsWith('video');
      })
      .toList(growable: false);
}

List<String> attachmentNameLines(List<Attachment> attachments) {
  if (attachments.isEmpty) return const [];
  final names = <String>[];
  for (final attachment in attachments) {
    final label = _attachmentDisplayName(attachment);
    if (label.isNotEmpty) names.add(label);
  }
  return names;
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
  _activeAttachmentToast?.remove();
  _activeAttachmentToast = null;
  final overlay = Overlay.of(context, rootOverlay: true);

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

  final maxToastWidth = (screenSize.width -
          padding.left -
          padding.right -
          _toastMargin * 2)
      .clamp(0.0, screenSize.width);
  final maxTextWidthAllowed = (maxToastWidth - _toastHorizontalPadding * 2)
      .clamp(0.0, maxToastWidth);
  final displayLines = <String>[];
  final textPainter = TextPainter(
    textDirection: textDirection,
    maxLines: 1,
    ellipsis: '…',
  );
  for (final line in lines) {
    displayLines.add(
      _truncateMiddleToFit(
        line,
        textPainter,
        textStyle,
        maxTextWidthAllowed,
      ),
    );
  }

  double maxTextWidth = 0;
  double lineHeight = 0;
  for (final line in displayLines) {
    textPainter.text = TextSpan(text: line, style: textStyle);
    textPainter.layout();
    maxTextWidth = maxTextWidth < textPainter.width
        ? textPainter.width
        : maxTextWidth;
    lineHeight =
        lineHeight < textPainter.height ? textPainter.height : lineHeight;
  }
  if (lineHeight == 0) lineHeight = textStyle.fontSize ?? 12;
  final contentHeight = lineHeight * displayLines.length +
      _toastLineSpacing * (displayLines.length - 1);
  final rawWidth = maxTextWidth + _toastHorizontalPadding * 2;
  final rawHeight = contentHeight + _toastVerticalPadding * 2;
  final toastWidth = rawWidth.clamp(0.0, maxToastWidth);
  final maxToastHeight = (screenSize.height -
          padding.top -
          padding.bottom -
          _toastMargin * 2)
      .clamp(0.0, screenSize.height);
  final toastHeight = rawHeight.clamp(0.0, maxToastHeight);

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
        final scrollable = rawHeight > maxToastHeight && maxToastHeight > 0;
        return Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: toastWidth,
              maxHeight: scrollable ? maxToastHeight : double.infinity,
            ),
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
              child: ClipRect(
                child: scrollable
                    ? SingleChildScrollView(
                        child: _buildToastLines(displayLines, textStyle),
                      )
                    : _buildToastLines(displayLines, textStyle),
              ),
            ),
          ),
        );
      }

      if (anchorPoint == null) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _activeAttachmentToast?.remove();
                  _activeAttachmentToast = null;
                },
                child: const SizedBox.shrink(),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: toastBody(),
                ),
              ),
            ),
          ],
        );
      }

      final minLeft = padding.left + _toastMargin;
      final maxLeft =
          screenSize.width - padding.right - _toastMargin - toastWidth;
      var left = anchorPoint.dx;
      if (left > maxLeft) left = maxLeft;
      if (left < minLeft) left = minLeft;

      final minTop = padding.top + _toastMargin;
      final maxTop =
          screenSize.height - padding.bottom - _toastMargin - toastHeight;
      var top = anchorPoint.dy + _toastGap;
      if (top > maxTop) {
        top = anchorPoint.dy - _toastGap - toastHeight;
      }
      if (top < minTop) top = minTop;

      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _activeAttachmentToast?.remove();
                _activeAttachmentToast = null;
              },
              child: const SizedBox.shrink(),
            ),
          ),
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
  _activeAttachmentToast = entry;
}

Widget _buildToastLines(List<String> lines, TextStyle textStyle) {
  return Column(
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
  );
}

String _truncateMiddleToFit(
  String text,
  TextPainter painter,
  TextStyle style,
  double maxWidth,
) {
  if (text.isEmpty) return text;
  painter.text = TextSpan(text: text, style: style);
  painter.layout();
  if (painter.width <= maxWidth) return text;

  final tail = _tailSegment(text);
  final ellipsis = _toastEllipsis;
  var low = 1;
  var high = text.length - tail.length;
  if (high < low) {
    return text;
  }
  var best = '${text.substring(0, low)}$ellipsis$tail';
  while (low <= high) {
    final mid = (low + high) >> 1;
    final candidate = '${text.substring(0, mid)}$ellipsis$tail';
    painter.text = TextSpan(text: candidate, style: style);
    painter.layout();
    if (painter.width <= maxWidth) {
      best = candidate;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return best;
}

String _tailSegment(String text) {
  final idx = text.lastIndexOf('.');
  if (idx > 0 && idx < text.length - 1) {
    final ext = text.substring(idx);
    if (ext.length <= 8) return ext;
  }
  if (text.length <= 4) return text;
  return text.substring(text.length - 4);
}
