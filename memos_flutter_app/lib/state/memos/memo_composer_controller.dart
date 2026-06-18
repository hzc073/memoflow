import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/markdown_editing.dart';
import '../../core/tags.dart';
import 'memo_composer_state.dart';
import 'memo_tag_autocomplete.dart';
import 'memos_providers.dart';

class MemoComposerController extends ChangeNotifier {
  MemoComposerController({
    String initialText = '',
    TextSelection? initialSelection,
    int maxHistory = 100,
  }) : _maxHistory = maxHistory,
       textController = TextEditingController(text: initialText) {
    final selection = initialSelection;
    if (selection != null) {
      textController.selection = _normalizeSelection(
        selection,
        textController.text.length,
      );
    }
    _smartEnterController = SmartEnterController(textController);
    _lastValue = textController.value;
    textController.addListener(_trackHistory);
  }

  final TextEditingController textController;
  final int _maxHistory;
  late final SmartEnterController _smartEnterController;
  final List<TextEditingValue> _undoStack = <TextEditingValue>[];
  final List<TextEditingValue> _redoStack = <TextEditingValue>[];
  late TextEditingValue _lastValue;
  bool _isApplyingHistory = false;
  MemoComposerState _state = const MemoComposerState();

  MemoComposerState get state => _state;
  List<MemoComposerPendingAttachment> get pendingAttachments =>
      _state.pendingAttachments;
  List<MemoComposerPendingAttachment> get unreadyPendingAttachments => _state
      .pendingAttachments
      .where((attachment) => !attachment.isReadyForSubmit)
      .toList(growable: false);
  bool get hasUnreadyPendingAttachments => unreadyPendingAttachments.isNotEmpty;
  int get readyPendingAttachmentCount => _state.pendingAttachments
      .where((attachment) => attachment.isReadyForSubmit)
      .length;
  List<MemoComposerLinkedMemo> get linkedMemos => _state.linkedMemos;
  int get tagAutocompleteIndex => _state.tagAutocompleteIndex;
  String? get tagAutocompleteToken => _state.tagAutocompleteToken;
  bool get canUndo => _state.canUndo;
  bool get canRedo => _state.canRedo;
  String get text => textController.text;
  Set<String> get linkedMemoNames =>
      linkedMemos.map((memo) => memo.name).toSet();

  @override
  void dispose() {
    textController.removeListener(_trackHistory);
    _smartEnterController.dispose();
    textController.dispose();
    super.dispose();
  }

  static TextSelection _normalizeSelection(
    TextSelection selection,
    int length,
  ) {
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: length);
    }
    int clampOffset(int offset) => offset.clamp(0, length).toInt();
    return selection.copyWith(
      baseOffset: clampOffset(selection.baseOffset),
      extentOffset: clampOffset(selection.extentOffset),
    );
  }

  void _trackHistory() {
    if (_isApplyingHistory) return;
    final value = textController.value;
    if (value.text == _lastValue.text &&
        value.selection == _lastValue.selection) {
      return;
    }
    _undoStack.add(_lastValue);
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    _lastValue = value;
    _updateState(
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
    );
  }

  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    _lastValue = textController.value;
    _updateState(canUndo: false, canRedo: false);
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _isApplyingHistory = true;
    final current = textController.value;
    final previous = _undoStack.removeLast();
    _redoStack.add(current);
    textController.value = previous;
    _lastValue = previous;
    _isApplyingHistory = false;
    _updateState(
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
    );
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _isApplyingHistory = true;
    final current = textController.value;
    final next = _redoStack.removeLast();
    _undoStack.add(current);
    textController.value = next;
    _lastValue = next;
    _isApplyingHistory = false;
    _updateState(
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
    );
  }

  void insertText(String text, {int? caretOffset}) {
    textController.value = insertInlineSnippet(
      textController.value,
      text,
      caretOffset: caretOffset,
    );
  }

  void replaceText(String text, {bool clearHistory = false}) {
    textController.value = textController.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
    if (clearHistory) {
      this.clearHistory();
    }
  }

  void applyTemplateContent(String renderedText) {
    replaceText(renderedText);
  }

  void insertUnorderedListMarker() {
    toggleUnorderedList();
  }

  void insertOrderedListMarker() {
    toggleOrderedList();
  }

  void insertTaskCheckbox() {
    toggleTaskList();
  }

  void insertCodeBlock() {
    textController.value = insertBlockSnippet(
      textController.value,
      '```\n\n```',
      caretOffset: 4,
    );
  }

  bool applyDesktopSmartEnter({String lineBreak = '\n'}) {
    final nextValue = SmartEnterController.applySmartEnterKeyPress(
      textController.value,
      lineBreak: lineBreak,
    );
    if (nextValue == null) return false;
    _smartEnterController.applyValue(nextValue);
    return true;
  }

  void toggleBold() {
    textController.value = wrapMarkdownSelection(
      textController.value,
      prefix: '**',
      suffix: '**',
    );
  }

  void toggleItalic() {
    textController.value = wrapMarkdownSelection(
      textController.value,
      prefix: '*',
      suffix: '*',
    );
  }

  void toggleStrikethrough() {
    textController.value = wrapMarkdownSelection(
      textController.value,
      prefix: '~~',
      suffix: '~~',
    );
  }

  void toggleInlineCode() {
    textController.value = wrapMarkdownSelection(
      textController.value,
      prefix: '`',
      suffix: '`',
    );
  }

  void toggleUnderline() {
    textController.value = wrapMarkdownSelection(
      textController.value,
      prefix: '<u>',
      suffix: '</u>',
    );
  }

  void toggleHighlight() {
    textController.value = wrapMarkdownSelection(
      textController.value,
      prefix: '==',
      suffix: '==',
    );
  }

  void toggleUnorderedList() {
    textController.value = toggleBlockStyle(
      textController.value,
      MarkdownBlockStyle.unorderedList,
    );
  }

  void toggleOrderedList() {
    textController.value = toggleBlockStyle(
      textController.value,
      MarkdownBlockStyle.orderedList,
    );
  }

  void toggleTaskList() {
    textController.value = toggleBlockStyle(
      textController.value,
      MarkdownBlockStyle.taskList,
    );
  }

  void toggleHeading1() {
    textController.value = toggleBlockStyle(
      textController.value,
      MarkdownBlockStyle.heading1,
    );
  }

  void toggleHeading2() {
    textController.value = toggleBlockStyle(
      textController.value,
      MarkdownBlockStyle.heading2,
    );
  }

  void toggleHeading3() {
    textController.value = toggleBlockStyle(
      textController.value,
      MarkdownBlockStyle.heading3,
    );
  }

  void toggleQuote() {
    textController.value = toggleBlockStyle(
      textController.value,
      MarkdownBlockStyle.quote,
    );
  }

  void insertDivider() {
    textController.value = insertBlockSnippet(
      textController.value,
      '---',
      caretOffset: 3,
    );
  }

  void insertInlineMath() {
    textController.value = insertInlineSnippet(
      textController.value,
      r'$$',
      caretOffset: 1,
    );
  }

  void insertBlockMath() {
    const blockMath = '\$\$\n\n\$\$';
    textController.value = insertBlockSnippet(
      textController.value,
      blockMath,
      caretOffset: 3,
    );
  }

  void insertTableTemplate() {
    const table =
        '| Column 1 | Column 2 |\n| --- | --- |\n| Value 1 | Value 2 |';
    textController.value = insertBlockSnippet(
      textController.value,
      table,
      caretOffset: 2,
    );
  }

  Future<bool> cutCurrentParagraphs() async {
    final result = cutParagraphs(textController.value);
    if (result == null) return false;
    try {
      await Clipboard.setData(ClipboardData(text: result.copiedText));
    } catch (_) {
      return false;
    }
    textController.value = result.value;
    return true;
  }

  ActiveTagQuery? activeTagQuery({
    TagRecognitionPolicy policy = TagRecognitionPolicy.defaultPolicy,
  }) => detectActiveTagQuery(textController.value, policy: policy);

  void syncTagAutocompleteState({
    required List<TagStat> tagStats,
    required bool hasFocus,
    TagRecognitionPolicy policy = TagRecognitionPolicy.defaultPolicy,
  }) {
    final query = activeTagQuery(policy: policy);
    final token = query == null
        ? null
        : '${query.start}:${query.query.toLowerCase()}';
    var nextIndex = _state.tagAutocompleteIndex;
    if (_state.tagAutocompleteToken != token) {
      nextIndex = 0;
    }

    final suggestions = currentTagSuggestions(
      tagStats,
      hasFocus: hasFocus,
      policy: policy,
    );
    if (suggestions.isEmpty) {
      nextIndex = 0;
    } else {
      nextIndex = nextIndex.clamp(0, suggestions.length - 1).toInt();
    }

    _updateState(tagAutocompleteToken: token, tagAutocompleteIndex: nextIndex);
  }

  List<TagStat> currentTagSuggestions(
    List<TagStat> tagStats, {
    required bool hasFocus,
    TagRecognitionPolicy policy = TagRecognitionPolicy.defaultPolicy,
  }) {
    if (!hasFocus) return const <TagStat>[];
    final query = activeTagQuery(policy: policy);
    if (query == null) return const <TagStat>[];
    return buildTagSuggestions(tagStats, query: query.query);
  }

  void setTagAutocompleteIndex(int index) {
    if (_state.tagAutocompleteIndex == index) return;
    _updateState(tagAutocompleteIndex: index);
  }

  KeyEventResult handleTagAutocompleteKeyEvent(
    KeyEvent event, {
    required List<TagStat> tagStats,
    required bool hasFocus,
    TagRecognitionPolicy policy = TagRecognitionPolicy.defaultPolicy,
    VoidCallback? requestFocus,
  }) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final query = activeTagQuery(policy: policy);
    final suggestions = currentTagSuggestions(
      tagStats,
      hasFocus: hasFocus,
      policy: policy,
    );
    if (query == null || suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setTagAutocompleteIndex(
        (_state.tagAutocompleteIndex + 1) % suggestions.length,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setTagAutocompleteIndex(
        (_state.tagAutocompleteIndex - 1 + suggestions.length) %
            suggestions.length,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final selectedIndex = _state.tagAutocompleteIndex
          .clamp(0, suggestions.length - 1)
          .toInt();
      applyTagSuggestion(
        query,
        suggestions[selectedIndex],
        requestFocus: requestFocus,
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void startTagAutocomplete({
    TagRecognitionPolicy policy = TagRecognitionPolicy.defaultPolicy,
    VoidCallback? requestFocus,
  }) {
    if (activeTagQuery(policy: policy) == null) {
      insertText('#');
    }
    _updateState(tagAutocompleteIndex: 0);
    requestFocus?.call();
  }

  void applyTagSuggestion(
    ActiveTagQuery query,
    TagStat tag, {
    VoidCallback? requestFocus,
  }) {
    final value = textController.value;
    final selection = value.selection;
    final end = selection.isValid && selection.isCollapsed
        ? selection.extentOffset.clamp(query.start, value.text.length).toInt()
        : query.end;
    final replacement = '#${tag.path} ';
    final nextText = value.text.replaceRange(query.start, end, replacement);
    final caret = query.start + replacement.length;
    textController.value = value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.empty,
    );
    _updateState(tagAutocompleteIndex: 0, tagAutocompleteToken: null);
    requestFocus?.call();
  }

  void setPendingAttachments(
    Iterable<MemoComposerPendingAttachment> attachments,
  ) {
    _updateState(
      pendingAttachments: List<MemoComposerPendingAttachment>.from(attachments),
    );
  }

  void addPendingAttachments(
    Iterable<MemoComposerPendingAttachment> attachments,
  ) {
    final existingUids = _state.pendingAttachments
        .map((attachment) => attachment.uid)
        .toSet();
    final added = <MemoComposerPendingAttachment>[];
    for (final attachment in attachments) {
      if (!existingUids.add(attachment.uid)) {
        continue;
      }
      added.add(attachment);
    }
    if (added.isEmpty) return;
    _updateState(
      pendingAttachments: <MemoComposerPendingAttachment>[
        ..._state.pendingAttachments,
        ...added,
      ],
    );
  }

  bool removePendingAttachment(String uid) {
    final next = _state.pendingAttachments
        .where((attachment) => attachment.uid != uid)
        .toList(growable: false);
    if (next.length == _state.pendingAttachments.length) {
      return false;
    }
    _updateState(pendingAttachments: next);
    return true;
  }

  bool replacePendingAttachment(
    String uid,
    MemoComposerPendingAttachment attachment,
  ) {
    final index = _state.pendingAttachments.indexWhere(
      (item) => item.uid == uid,
    );
    if (index < 0) return false;
    final next = List<MemoComposerPendingAttachment>.from(
      _state.pendingAttachments,
    );
    next[index] = attachment;
    _updateState(pendingAttachments: next);
    return true;
  }

  bool updatePendingAttachment(
    String uid,
    MemoComposerPendingAttachment Function(
      MemoComposerPendingAttachment current,
    )
    update,
  ) {
    final index = _state.pendingAttachments.indexWhere(
      (item) => item.uid == uid,
    );
    if (index < 0) return false;
    final next = List<MemoComposerPendingAttachment>.from(
      _state.pendingAttachments,
    );
    next[index] = update(next[index]);
    _updateState(pendingAttachments: next);
    return true;
  }

  void clearPendingAttachments() {
    if (_state.pendingAttachments.isEmpty) return;
    _updateState(pendingAttachments: const <MemoComposerPendingAttachment>[]);
  }

  void setLinkedMemos(Iterable<MemoComposerLinkedMemo> memos) {
    _updateState(linkedMemos: List<MemoComposerLinkedMemo>.from(memos));
  }

  bool addLinkedMemo(MemoComposerLinkedMemo memo) {
    if (_state.linkedMemos.any((item) => item.name == memo.name)) {
      return false;
    }
    _updateState(
      linkedMemos: <MemoComposerLinkedMemo>[..._state.linkedMemos, memo],
    );
    return true;
  }

  bool removeLinkedMemo(String name) {
    final next = _state.linkedMemos
        .where((memo) => memo.name != name)
        .toList(growable: false);
    if (next.length == _state.linkedMemos.length) return false;
    _updateState(linkedMemos: next);
    return true;
  }

  void clearLinkedMemos() {
    if (_state.linkedMemos.isEmpty) return;
    _updateState(linkedMemos: const <MemoComposerLinkedMemo>[]);
  }

  void _updateState({
    List<MemoComposerPendingAttachment>? pendingAttachments,
    List<MemoComposerLinkedMemo>? linkedMemos,
    int? tagAutocompleteIndex,
    Object? tagAutocompleteToken = memoComposerStateNoChange,
    bool? canUndo,
    bool? canRedo,
  }) {
    _state = _state.copyWith(
      pendingAttachments: pendingAttachments,
      linkedMemos: linkedMemos,
      tagAutocompleteIndex: tagAutocompleteIndex,
      tagAutocompleteToken: tagAutocompleteToken,
      canUndo: canUndo,
      canRedo: canRedo,
    );
    notifyListeners();
  }
}
