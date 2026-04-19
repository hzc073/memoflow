import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../i18n/strings.g.dart';
import '../../state/memos/memo_composer_controller.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../memos/tag_autocomplete.dart';
import 'share_handler.dart';
import 'share_quick_clip_models.dart';

Future<ShareQuickClipSubmission?> showShareQuickClipSheet(
  BuildContext context, {
  required SharePayload payload,
  String? initialTagText,
  bool initialTextOnly = false,
  bool initialTitleAndLinkOnly = false,
}) {
  return showModalBottomSheet<ShareQuickClipSubmission>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.08),
    builder: (_) => _ShareQuickClipSheet(
      payload: payload,
      initialTagText: initialTagText ?? buildDefaultQuickClipTagText(payload),
      initialTextOnly: initialTextOnly,
      initialTitleAndLinkOnly: initialTitleAndLinkOnly,
    ),
  );
}

class _ShareQuickClipSheet extends ConsumerStatefulWidget {
  const _ShareQuickClipSheet({
    required this.payload,
    required this.initialTagText,
    required this.initialTextOnly,
    required this.initialTitleAndLinkOnly,
  });

  final SharePayload payload;
  final String initialTagText;
  final bool initialTextOnly;
  final bool initialTitleAndLinkOnly;

  @override
  ConsumerState<_ShareQuickClipSheet> createState() =>
      _ShareQuickClipSheetState();
}

class _ShareQuickClipSheetState extends ConsumerState<_ShareQuickClipSheet> {
  late final MemoComposerController _tagComposer;
  late final TextEditingController _tagController;
  late final FocusNode _tagFocusNode;
  final _tagFieldKey = GlobalKey();
  late bool _textOnly;
  late bool _titleAndLinkOnly;
  int get _tagAutocompleteIndex => _tagComposer.tagAutocompleteIndex;

  @override
  void initState() {
    super.initState();
    _tagComposer = MemoComposerController(initialText: widget.initialTagText);
    _tagController = _tagComposer.textController;
    _tagFocusNode = FocusNode();
    _tagController.addListener(_handleTagInputChanged);
    _tagFocusNode.addListener(_handleTagInputChanged);
    _titleAndLinkOnly = widget.initialTitleAndLinkOnly;
    _textOnly = _titleAndLinkOnly ? false : widget.initialTextOnly;
  }

  @override
  void dispose() {
    _tagController.removeListener(_handleTagInputChanged);
    _tagFocusNode.removeListener(_handleTagInputChanged);
    _tagFocusNode.dispose();
    _tagComposer.dispose();
    super.dispose();
  }

  void _handleTagInputChanged() {
    if (!mounted) return;
    _syncTagAutocompleteState();
    setState(() {});
  }

  List<TagStat> _currentTagStats() {
    return ref.read(tagStatsProvider).valueOrNull ?? const <TagStat>[];
  }

  void _syncTagAutocompleteState() {
    _tagComposer.syncTagAutocompleteState(
      tagStats: _currentTagStats(),
      hasFocus: _tagFocusNode.hasFocus,
    );
  }

  KeyEventResult _handleTagAutocompleteKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    final result = _tagComposer.handleTagAutocompleteKeyEvent(
      event,
      tagStats: _currentTagStats(),
      hasFocus: _tagFocusNode.hasFocus,
      requestFocus: _tagFocusNode.requestFocus,
    );
    if (result == KeyEventResult.handled) {
      setState(() {});
    }
    return result;
  }

  void _applyTagSuggestion(ActiveTagQuery query, TagStat tag) {
    _tagComposer.applyTagSuggestion(
      query,
      tag,
      requestFocus: _tagFocusNode.requestFocus,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final tileColor = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final tagTextStyle =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    final url = extractShareUrl((widget.payload.text ?? '').trim()) ?? '';
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.9;
    final tagStats =
        ref.watch(tagStatsProvider).valueOrNull ?? const <TagStat>[];
    final tagColorLookup = TagColorLookup(tagStats);
    final activeTagQuery = _tagComposer.activeTagQuery;
    final tagSuggestions = _tagComposer.currentTagSuggestions(
      tagStats,
      hasFocus: _tagFocusNode.hasFocus,
    );
    final highlightedTagSuggestionIndex = tagSuggestions.isEmpty
        ? 0
        : _tagAutocompleteIndex.clamp(0, tagSuggestions.length - 1).toInt();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsetsBottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Container(
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(
                    color: borderColor.withValues(alpha: isDark ? 0.5 : 0.8),
                  ),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _title(context),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: textColor.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tileColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        url,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textColor.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        KeyedSubtree(
                          key: _tagFieldKey,
                          child: Focus(
                            canRequestFocus: false,
                            onKeyEvent: _handleTagAutocompleteKeyEvent,
                            child: TextField(
                              controller: _tagController,
                              focusNode: _tagFocusNode,
                              style: tagTextStyle,
                              decoration: InputDecoration(
                                labelText: context.t.strings.legacy.msg_tags,
                                hintText: _tagHint(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        if (_tagFocusNode.hasFocus &&
                            activeTagQuery != null &&
                            tagSuggestions.isNotEmpty)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: TagAutocompleteOverlay(
                                editorKey: _tagFieldKey,
                                value: _tagController.value,
                                textStyle: tagTextStyle,
                                tags: tagSuggestions,
                                tagColors: tagColorLookup,
                                highlightedIndex: highlightedTagSuggestionIndex,
                                onHighlight: (index) {
                                  if (_tagAutocompleteIndex == index) {
                                    return;
                                  }
                                  setState(() {
                                    _tagComposer.setTagAutocompleteIndex(index);
                                  });
                                },
                                onSelect: (tag) =>
                                    _applyTagSuggestion(activeTagQuery, tag),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _titleAndLinkOnlyLabel(context),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: textColor),
                      ),
                      value: _titleAndLinkOnly,
                      onChanged: (value) {
                        setState(() {
                          _titleAndLinkOnly = value;
                          if (value) {
                            _textOnly = false;
                          }
                        });
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _textOnlyLabel(context),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: textColor),
                      ),
                      value: _textOnly,
                      onChanged: (value) {
                        setState(() {
                          _textOnly = value;
                          if (value) {
                            _titleAndLinkOnly = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(context.t.strings.legacy.msg_close),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).pop(
                                ShareQuickClipSubmission(
                                  tags: normalizeQuickClipTags(
                                    _tagController.text,
                                  ),
                                  textOnly: _textOnly,
                                  titleAndLinkOnly: _titleAndLinkOnly,
                                ),
                              );
                            },
                            child: Text(_confirmLabel(context)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _title(BuildContext context) {
    return _isZh(context)
        ? '\u68c0\u6d4b\u5230\u526a\u8d34\u677f\u94fe\u63a5\uff0c\u53ef\u76f4\u63a5\u526a\u85cf'
        : 'Clipboard link detected. You can clip it now.';
  }

  String _tagHint(BuildContext context) {
    return _isZh(context) ? '#\u6807\u7b7e1 #\u6807\u7b7e2' : '#tag1 #tag2';
  }

  String _textOnlyLabel(BuildContext context) {
    return _isZh(context) ? '\u4ec5\u4fdd\u5b58\u6587\u5b57' : 'Save text only';
  }

  String _titleAndLinkOnlyLabel(BuildContext context) {
    return _isZh(context)
        ? '\u4ec5\u4fdd\u5b58\u6807\u9898\u548c\u94fe\u63a5'
        : 'Save title and link only';
  }

  String _confirmLabel(BuildContext context) {
    return _isZh(context) ? '\u7acb\u5373\u526a\u85cf' : 'Clip now';
  }

  bool _isZh(BuildContext context) {
    return isZhLocale(context);
  }
}

bool isZhLocale(BuildContext context) {
  return Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('zh');
}

String buildDefaultQuickClipTagText(SharePayload payload) {
  final raw = extractShareUrl((payload.text ?? '').trim());
  final uri = raw == null ? null : Uri.tryParse(raw);
  final host = uri?.host.toLowerCase() ?? '';
  if (host == 'mp.weixin.qq.com' || host.endsWith('.mp.weixin.qq.com')) {
    return '#\u516c\u4f17\u53f7';
  }
  return '';
}

List<String> normalizeQuickClipTags(String raw) {
  final normalized = raw.replaceAll(RegExp(r'[\n\r,;]+'), ' ').trim();
  if (normalized.isEmpty) return const <String>[];
  final tags = <String>[];
  for (final segment in normalized.split(RegExp(r'\s+'))) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) continue;
    final value = trimmed.startsWith('#') ? trimmed : '#$trimmed';
    if (!tags.contains(value)) {
      tags.add(value);
    }
  }
  return tags;
}
