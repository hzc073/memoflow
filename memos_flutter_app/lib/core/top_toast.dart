import 'dart:async';

import 'package:flutter/material.dart';

import 'memoflow_palette.dart';

const Duration _defaultToastDuration = Duration(seconds: 4);
OverlayEntry? _activeTopToast;
Timer? _topToastTimer;

bool showTopToast(
  BuildContext context,
  String message, {
  Duration duration = _defaultToastDuration,
  double topOffset = 144,
  bool retryIfOverlayMissing = true,
}) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) return false;
  if (context is Element && !context.mounted) return false;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    if (retryIfOverlayMissing && context is Element && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showTopToast(
          context,
          trimmed,
          duration: duration,
          topOffset: topOffset,
          retryIfOverlayMissing: false,
        );
      });
    }
    return false;
  }

  _topToastTimer?.cancel();
  _topToastTimer = null;
  _activeTopToast?.remove();
  _activeTopToast = null;

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final toastBg = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
  final toastText = isDark
      ? MemoFlowPalette.textDark
      : MemoFlowPalette.textLight;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: topOffset),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              child: Text(
                trimmed,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: toastText,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  _activeTopToast = entry;
  _topToastTimer = Timer(duration, () {
    if (entry.mounted) {
      entry.remove();
    }
    if (_activeTopToast == entry) {
      _activeTopToast = null;
    }
  });
  return true;
}

void dismissTopToast() {
  _topToastTimer?.cancel();
  _topToastTimer = null;
  _activeTopToast?.remove();
  _activeTopToast = null;
}
