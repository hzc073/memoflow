import 'package:flutter/material.dart';

class SmartEnterResult {
  const SmartEnterResult({
    required this.text,
    required this.selection,
  });

  final String text;
  final TextSelection selection;
}

class SmartEnterController {
  SmartEnterController(this.controller) {
    _lastText = controller.text;
    controller.addListener(_handleChange);
  }

  final TextEditingController controller;
  late String _lastText;
  bool _applying = false;

  static final RegExp _taskPrefixRegex =
      RegExp(r'^(\s*(?:- \[(?: |x|X)\] |- ))');

  void dispose() {
    controller.removeListener(_handleChange);
  }

  void _handleChange() {
    if (_applying) return;

    final newText = controller.text;
    final result = handleSmartEnter(_lastText, newText);
    if (result != null) {
      _applying = true;
      controller.value = controller.value.copyWith(
        text: result.text,
        selection: result.selection,
        composing: TextRange.empty,
      );
      _applying = false;
    }
    _lastText = controller.text;
  }

  SmartEnterResult? handleSmartEnter(String oldText, String newText) {
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;

    final cursor = selection.baseOffset;
    if (cursor <= 0 || cursor > newText.length) return null;

    // Only handle single newline insertion to avoid paste/replace cases.
    if (newText.length != oldText.length + 1) return null;
    if (newText[cursor - 1] != '\n') return null;

    // Look at the line before the cursor.
    final prevLineStart = newText.lastIndexOf('\n', cursor - 2) + 1;
    final prevLine = newText.substring(prevLineStart, cursor - 1);

    final match = _taskPrefixRegex.firstMatch(prevLine);
    if (match == null) return null;

    final prefix = match.group(1)!;
    final rest = prevLine.substring(prefix.length);
    final isPrefixOnly = rest.trim().isEmpty;

    if (isPrefixOnly) {
      // Double enter: remove the empty list prefix and move cursor back.
      final updated = newText.replaceRange(
        prevLineStart,
        prevLineStart + prefix.length,
        '',
      );
      final newCursor = (cursor - prefix.length).clamp(0, updated.length);
      return SmartEnterResult(
        text: updated,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    // Normal enter: insert the same prefix on the next line.
    final updated = newText.replaceRange(cursor, cursor, prefix);
    final newCursor = cursor + prefix.length;
    return SmartEnterResult(
      text: updated,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}
