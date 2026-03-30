import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform_layout.dart';
import '../../state/memos/memo_composer_controller.dart';
import '../../state/memos/memos_providers.dart';
import '../../i18n/strings.g.dart';

typedef MemosListInlineDraftListener =
    ProviderSubscription<AsyncValue<String>> Function(
      void Function(AsyncValue<String> value) listener,
    );

@immutable
class MemosListInlineVisibilityPresentation {
  const MemosListInlineVisibilityPresentation({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class MemosListInlineComposeUiController extends ChangeNotifier {
  MemosListInlineComposeUiController({
    required MemoComposerController composer,
    required FocusNode focusNode,
    required List<TagStat> Function() currentTagStats,
    required AsyncValue<String> Function() readDraft,
    required MemosListInlineDraftListener listenDraft,
    required FutureOr<void> Function(String value) saveDraft,
    required bool Function() busy,
  }) : _composer = composer,
       _focusNode = focusNode,
       _currentTagStats = currentTagStats,
       _readDraft = readDraft,
       _listenDraft = listenDraft,
       _saveDraft = saveDraft,
       _busy = busy;

  final MemoComposerController _composer;
  final FocusNode _focusNode;
  final List<TagStat> Function() _currentTagStats;
  final AsyncValue<String> Function() _readDraft;
  final MemosListInlineDraftListener _listenDraft;
  final FutureOr<void> Function(String value) _saveDraft;
  final bool Function() _busy;

  bool _draftApplied = false;
  Timer? _draftSaveTimer;
  ProviderSubscription<AsyncValue<String>>? _draftSubscription;

  bool get draftApplied => _draftApplied;
  Timer? get draftSaveTimer => _draftSaveTimer;
  ProviderSubscription<AsyncValue<String>>? get draftSubscription =>
      _draftSubscription;
  bool get canUndo => _composer.canUndo;
  bool get canRedo => _composer.canRedo;

  void attachDraftSync() {
    applyDraft(_readDraft());
    _draftSubscription ??= _listenDraft(applyDraft);
  }

  void applyDraft(AsyncValue<String> value) {
    if (_draftApplied) return;
    final draft = value.valueOrNull;
    if (draft == null) return;
    if (_composer.textController.text.trim().isEmpty &&
        draft.trim().isNotEmpty) {
      _composer.textController.text = draft;
      _composer.textController.selection = TextSelection.collapsed(
        offset: draft.length,
      );
    }
    _draftApplied = true;
    notifyListeners();
  }

  void scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    final text = _composer.textController.text;
    _draftSaveTimer = Timer(const Duration(milliseconds: 300), () {
      _saveDraft(text);
    });
  }

  void cancelDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = null;
  }

  void handleComposerChanged() {
    syncTagAutocompleteState();
    scheduleDraftSave();
    notifyListeners();
  }

  void handleFocusChanged() {
    syncTagAutocompleteState();
    notifyListeners();
  }

  void syncTagAutocompleteState() {
    _composer.syncTagAutocompleteState(
      tagStats: currentInlineTagStats(),
      hasFocus: _focusNode.hasFocus,
    );
  }

  List<TagStat> currentInlineTagStats() {
    return _currentTagStats();
  }

  void undo() {
    if (!canUndo || _busy()) return;
    _composer.undo();
    notifyListeners();
  }

  void redo() {
    if (!canRedo || _busy()) return;
    _composer.redo();
    notifyListeners();
  }

  void toggleBold() {
    _composer.toggleBold();
    notifyListeners();
  }

  void toggleUnderline() {
    _composer.toggleUnderline();
    notifyListeners();
  }

  void toggleHighlight() {
    _composer.toggleHighlight();
    notifyListeners();
  }

  void toggleUnorderedList() {
    _composer.toggleUnorderedList();
    notifyListeners();
  }

  void toggleOrderedList() {
    _composer.toggleOrderedList();
    notifyListeners();
  }

  Future<void> cutCurrentParagraphs() async {
    await _composer.cutCurrentParagraphs();
    notifyListeners();
  }

  MemosListInlineVisibilityPresentation resolveInlineVisibilityPresentation(
    BuildContext context,
    String raw,
  ) {
    switch (raw.trim().toUpperCase()) {
      case 'PUBLIC':
        return MemosListInlineVisibilityPresentation(
          label: context.t.strings.legacy.msg_public,
          icon: Icons.public,
          color: const Color(0xFF3B8C52),
        );
      case 'PROTECTED':
        return MemosListInlineVisibilityPresentation(
          label: context.t.strings.legacy.msg_protected,
          icon: Icons.verified_user,
          color: const Color(0xFFB26A2B),
        );
      default:
        return MemosListInlineVisibilityPresentation(
          label: context.t.strings.legacy.msg_private_2,
          icon: Icons.lock,
          color: const Color(0xFF7C7C7C),
        );
    }
  }

  bool shouldUseInlineComposeForCurrentWindow({
    required bool enableCompose,
    required bool searching,
    required double screenWidth,
  }) {
    if (!enableCompose || searching) {
      return false;
    }
    return shouldUseInlineComposeLayout(screenWidth);
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _draftSubscription?.close();
    super.dispose();
  }
}
