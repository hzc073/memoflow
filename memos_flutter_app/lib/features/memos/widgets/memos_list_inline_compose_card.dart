import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/image_thumbnail_cache.dart';
import '../../../core/measure_size.dart';
import '../../../core/markdown_editing.dart';
import '../../../core/memoflow_palette.dart';
import '../../../data/models/memo_location.dart';
import '../../../data/models/memo_template_settings.dart';
import '../../image_preview/image_preview_item.dart';
import '../../image_preview/widgets/image_preview_tile.dart';
import '../../../state/memos/memo_composer_controller.dart';
import '../../../state/memos/memo_composer_state.dart';
import '../../../state/tags/tag_color_lookup.dart';
import '../../../state/memos/memos_providers.dart';
import '../compose_toolbar_shared.dart';
import '../compose_input_hint.dart';
import '../memo_video_grid.dart';
import '../tag_autocomplete.dart';
import '../../../i18n/strings.g.dart';

class InlineComposeLayoutMetrics {
  const InlineComposeLayoutMetrics({
    required this.totalHeight,
    required this.editorViewportHeight,
  });

  final double totalHeight;
  final double editorViewportHeight;
}

class MemosListInlineComposeCard extends StatelessWidget {
  const MemosListInlineComposeCard({
    super.key,
    required this.composer,
    required this.focusNode,
    required this.pendingDraftCount,
    required this.busy,
    required this.locating,
    required this.location,
    required this.visibility,
    required this.visibilityTouched,
    required this.visibilityLabel,
    required this.visibilityIcon,
    required this.visibilityColor,
    required this.isDark,
    required this.tagStats,
    required this.availableTemplates,
    required this.tagColorLookup,
    required this.toolbarPreferences,
    required this.editorFieldKey,
    required this.tagMenuKey,
    required this.templateMenuKey,
    required this.todoMenuKey,
    required this.visibilityMenuKey,
    required this.onSubmit,
    required this.onRemoveAttachment,
    required this.onOpenAttachment,
    required this.onRemoveLinkedMemo,
    required this.onRequestLocation,
    required this.onClearLocation,
    required this.onOpenTemplateMenu,
    required this.onPickGallery,
    required this.onPickFile,
    required this.onOpenLinkMemo,
    required this.onCaptureCamera,
    required this.onOpenDraftBox,
    required this.onOpenTodoMenu,
    required this.onOpenVisibilityMenu,
    required this.onCutParagraphs,
    this.desktopEditorViewportHeight,
    this.onLayoutMetricsChanged,
  });

  final MemoComposerController composer;
  final FocusNode focusNode;
  final int pendingDraftCount;
  final bool busy;
  final bool locating;
  final MemoLocation? location;
  final String visibility;
  final bool visibilityTouched;
  final String visibilityLabel;
  final IconData visibilityIcon;
  final Color visibilityColor;
  final bool isDark;
  final List<TagStat> tagStats;
  final List<MemoTemplate> availableTemplates;
  final TagColorLookup tagColorLookup;
  final MemoToolbarPreferences toolbarPreferences;
  final GlobalKey editorFieldKey;
  final GlobalKey tagMenuKey;
  final GlobalKey templateMenuKey;
  final GlobalKey todoMenuKey;
  final GlobalKey visibilityMenuKey;
  final VoidCallback onSubmit;
  final ValueChanged<String> onRemoveAttachment;
  final ValueChanged<MemoComposerPendingAttachment> onOpenAttachment;
  final ValueChanged<String> onRemoveLinkedMemo;
  final VoidCallback onRequestLocation;
  final VoidCallback onClearLocation;
  final VoidCallback onOpenTemplateMenu;
  final VoidCallback onPickGallery;
  final VoidCallback onPickFile;
  final VoidCallback onOpenLinkMemo;
  final VoidCallback onCaptureCamera;
  final VoidCallback onOpenDraftBox;
  final VoidCallback onOpenTodoMenu;
  final VoidCallback onOpenVisibilityMenu;
  final VoidCallback onCutParagraphs;
  final double? desktopEditorViewportHeight;
  final ValueChanged<InlineComposeLayoutMetrics>? onLayoutMetricsChanged;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final hintColor = textColor.withValues(alpha: isDark ? 0.42 : 0.55);
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : MemoFlowPalette.audioSurfaceLight;
    final chipText = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final inlineComposeMinLines = Platform.isWindows ? 3 : 1;
    final inlineComposeMaxLines = Platform.isWindows ? 8 : 5;
    final usesControlledDesktopHeight =
        desktopEditorViewportHeight != null && desktopEditorViewportHeight! > 0;

    return _InlineComposeMetricsReporter(
      onLayoutMetricsChanged: onLayoutMetricsChanged,
      childBuilder: ({required reportTotalSize, required reportEditorSize}) {
        return AnimatedBuilder(
          animation: Listenable.merge([composer, focusNode]),
          builder: (context, _) {
            final linkedMemos = composer.linkedMemos;
            final pendingAttachments = composer.pendingAttachments;
            return MeasureSize(
              onChange: reportTotalSize,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor.withValues(alpha: 0.75),
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InlineAttachmentPreview(
                      attachments: pendingAttachments,
                      busy: busy,
                      isDark: isDark,
                      onRemoveAttachment: onRemoveAttachment,
                      onOpenAttachment: onOpenAttachment,
                    ),
                    if (linkedMemos.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: linkedMemos
                              .map(
                                (memo) => InputChip(
                                  key: ValueKey<String>(
                                    'inline-linked-memo-${memo.name}',
                                  ),
                                  avatar: Icon(
                                    Icons.alternate_email_rounded,
                                    size: 16,
                                    color: chipText.withValues(alpha: 0.75),
                                  ),
                                  label: Text(
                                    memo.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: chipText,
                                    ),
                                  ),
                                  backgroundColor: chipBg,
                                  deleteIconColor: chipText.withValues(
                                    alpha: 0.55,
                                  ),
                                  onDeleted: busy
                                      ? null
                                      : () => onRemoveLinkedMemo(memo.name),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    if (locating)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.t.strings.legacy.msg_locating,
                              style: TextStyle(fontSize: 12, color: chipText),
                            ),
                          ],
                        ),
                      ),
                    if (location != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: InputChip(
                            key: const ValueKey<String>('inline-location-chip'),
                            avatar: Icon(
                              Icons.place_outlined,
                              size: 16,
                              color: chipText.withValues(alpha: 0.75),
                            ),
                            label: Text(
                              location!.displayText(fractionDigits: 6),
                              style: TextStyle(fontSize: 12, color: chipText),
                            ),
                            backgroundColor: chipBg,
                            deleteIconColor: chipText.withValues(alpha: 0.55),
                            onPressed: busy ? null : onRequestLocation,
                            onDeleted: busy ? null : onClearLocation,
                          ),
                        ),
                      ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: composer.textController,
                      builder: (context, value, _) {
                        final inlineEditorTextStyle = TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: textColor,
                        );
                        final shouldShowDraftHint = shouldShowComposeDraftHint(
                          enableDraftHint: true,
                          pendingDraftCount: pendingDraftCount,
                          hasCurrentComposeContent:
                              value.text.trim().isNotEmpty ||
                              composer.pendingAttachments.isNotEmpty ||
                              composer.linkedMemos.isNotEmpty ||
                              location != null,
                        );
                        final hintText = shouldShowDraftHint
                            ? context.t.strings.legacy
                                  .msg_draft_box_pending_hint(
                                    count: pendingDraftCount,
                                  )
                            : context.t.strings.legacy.msg_write_thoughts;
                        final inlineActiveTagQuery = focusNode.hasFocus
                            ? detectActiveTagQuery(value)
                            : null;
                        final inlineTagSuggestions =
                            inlineActiveTagQuery == null
                            ? const <TagStat>[]
                            : buildTagSuggestions(
                                tagStats,
                                query: inlineActiveTagQuery.query,
                              );
                        final highlightedInlineTagSuggestionIndex =
                            inlineTagSuggestions.isEmpty
                            ? 0
                            : composer.tagAutocompleteIndex
                                  .clamp(0, inlineTagSuggestions.length - 1)
                                  .toInt();
                        Widget editorRegion = Stack(
                          clipBehavior: Clip.none,
                          children: [
                            KeyedSubtree(
                              key: editorFieldKey,
                              child: Focus(
                                canRequestFocus: false,
                                onKeyEvent: (node, event) =>
                                    composer.handleTagAutocompleteKeyEvent(
                                      event,
                                      tagStats: tagStats,
                                      hasFocus: focusNode.hasFocus,
                                      requestFocus: focusNode.requestFocus,
                                    ),
                                child: TextField(
                                  key: const ValueKey<String>(
                                    'memos-inline-compose-text-field',
                                  ),
                                  controller: composer.textController,
                                  focusNode: focusNode,
                                  enabled: !busy,
                                  inputFormatters: const [
                                    SmartEnterTextInputFormatter(),
                                  ],
                                  minLines: usesControlledDesktopHeight
                                      ? null
                                      : inlineComposeMinLines,
                                  maxLines: usesControlledDesktopHeight
                                      ? null
                                      : inlineComposeMaxLines,
                                  expands: usesControlledDesktopHeight,
                                  keyboardType: TextInputType.multiline,
                                  style: inlineEditorTextStyle,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: hintText,
                                    hintStyle: TextStyle(color: hintColor),
                                  ),
                                ),
                              ),
                            ),
                            if (focusNode.hasFocus &&
                                inlineActiveTagQuery != null &&
                                inlineTagSuggestions.isNotEmpty)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: TagAutocompleteOverlay(
                                    editorKey: editorFieldKey,
                                    value: value,
                                    textStyle: inlineEditorTextStyle,
                                    tags: inlineTagSuggestions,
                                    tagColors: tagColorLookup,
                                    highlightedIndex:
                                        highlightedInlineTagSuggestionIndex,
                                    onHighlight:
                                        composer.setTagAutocompleteIndex,
                                    onSelect: (tag) =>
                                        composer.applyTagSuggestion(
                                          inlineActiveTagQuery,
                                          tag,
                                          requestFocus: focusNode.requestFocus,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        );
                        if (usesControlledDesktopHeight) {
                          editorRegion = SizedBox(
                            height: desktopEditorViewportHeight,
                            child: editorRegion,
                          );
                        }
                        return MeasureSize(
                          onChange: reportEditorSize,
                          child: editorRegion,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _InlineComposeToolbar(
                            composer: composer,
                            busy: busy,
                            isDark: isDark,
                            preferences: toolbarPreferences,
                            availableTemplates: availableTemplates,
                            visibility: visibility,
                            visibilityTouched: visibilityTouched,
                            visibilityLabel: visibilityLabel,
                            visibilityIcon: visibilityIcon,
                            visibilityColor: visibilityColor,
                            tagMenuKey: tagMenuKey,
                            templateMenuKey: templateMenuKey,
                            todoMenuKey: todoMenuKey,
                            visibilityMenuKey: visibilityMenuKey,
                            focusNode: focusNode,
                            locating: locating,
                            onOpenTemplateMenu: onOpenTemplateMenu,
                            onPickFile: onPickFile,
                            onPickGallery: onPickGallery,
                            onOpenTodoMenu: onOpenTodoMenu,
                            onOpenLinkMemo: onOpenLinkMemo,
                            onCaptureCamera: onCaptureCamera,
                            onOpenDraftBox: onOpenDraftBox,
                            onRequestLocation: onRequestLocation,
                            onOpenVisibilityMenu: onOpenVisibilityMenu,
                            onCutParagraphs: onCutParagraphs,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: composer.textController,
                          builder: (context, value, _) {
                            final showSend =
                                value.text.trim().isNotEmpty ||
                                composer.pendingAttachments.isNotEmpty;
                            return Material(
                              color: MemoFlowPalette.primary,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                key: const ValueKey<String>(
                                  'memos-inline-compose-send-button',
                                ),
                                borderRadius: BorderRadius.circular(10),
                                onTap: busy ? null : onSubmit,
                                child: SizedBox(
                                  width: 38,
                                  height: 30,
                                  child: Center(
                                    child: busy
                                        ? const SizedBox.square(
                                            dimension: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 160,
                                            ),
                                            transitionBuilder:
                                                (child, animation) {
                                                  return ScaleTransition(
                                                    scale: animation,
                                                    child: child,
                                                  );
                                                },
                                            child: Icon(
                                              showSend
                                                  ? Icons.send_rounded
                                                  : Icons.graphic_eq,
                                              key: ValueKey<bool>(showSend),
                                              size: showSend ? 18 : 20,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

typedef _InlineComposeMetricsReporterBuilder =
    Widget Function({
      required ValueChanged<Size> reportTotalSize,
      required ValueChanged<Size> reportEditorSize,
    });

class _InlineComposeMetricsReporter extends StatefulWidget {
  const _InlineComposeMetricsReporter({
    required this.childBuilder,
    required this.onLayoutMetricsChanged,
  });

  final _InlineComposeMetricsReporterBuilder childBuilder;
  final ValueChanged<InlineComposeLayoutMetrics>? onLayoutMetricsChanged;

  @override
  State<_InlineComposeMetricsReporter> createState() =>
      _InlineComposeMetricsReporterState();
}

class _InlineComposeMetricsReporterState
    extends State<_InlineComposeMetricsReporter> {
  double? _totalHeight;
  double? _editorViewportHeight;

  void _handleTotalSizeChanged(Size size) {
    if (_totalHeight == size.height) return;
    _totalHeight = size.height;
    _emitLayoutMetricsIfReady();
  }

  void _handleEditorSizeChanged(Size size) {
    if (_editorViewportHeight == size.height) return;
    _editorViewportHeight = size.height;
    _emitLayoutMetricsIfReady();
  }

  void _emitLayoutMetricsIfReady() {
    final callback = widget.onLayoutMetricsChanged;
    final totalHeight = _totalHeight;
    final editorViewportHeight = _editorViewportHeight;
    if (callback == null ||
        totalHeight == null ||
        editorViewportHeight == null) {
      return;
    }
    callback(
      InlineComposeLayoutMetrics(
        totalHeight: totalHeight,
        editorViewportHeight: editorViewportHeight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.childBuilder(
      reportTotalSize: _handleTotalSizeChanged,
      reportEditorSize: _handleEditorSizeChanged,
    );
  }
}

class _InlineComposeToolbar extends StatelessWidget {
  const _InlineComposeToolbar({
    required this.composer,
    required this.busy,
    required this.isDark,
    required this.preferences,
    required this.availableTemplates,
    required this.visibility,
    required this.visibilityTouched,
    required this.visibilityLabel,
    required this.visibilityIcon,
    required this.visibilityColor,
    required this.tagMenuKey,
    required this.templateMenuKey,
    required this.todoMenuKey,
    required this.visibilityMenuKey,
    required this.focusNode,
    required this.locating,
    required this.onOpenTemplateMenu,
    required this.onPickFile,
    required this.onPickGallery,
    required this.onOpenTodoMenu,
    required this.onOpenLinkMemo,
    required this.onCaptureCamera,
    required this.onOpenDraftBox,
    required this.onRequestLocation,
    required this.onOpenVisibilityMenu,
    required this.onCutParagraphs,
  });

  final MemoComposerController composer;
  final bool busy;
  final bool isDark;
  final MemoToolbarPreferences preferences;
  final List<MemoTemplate> availableTemplates;
  final String visibility;
  final bool visibilityTouched;
  final String visibilityLabel;
  final IconData visibilityIcon;
  final Color visibilityColor;
  final GlobalKey tagMenuKey;
  final GlobalKey templateMenuKey;
  final GlobalKey todoMenuKey;
  final GlobalKey visibilityMenuKey;
  final FocusNode focusNode;
  final bool locating;
  final VoidCallback onOpenTemplateMenu;
  final VoidCallback onPickFile;
  final VoidCallback onPickGallery;
  final VoidCallback onOpenTodoMenu;
  final VoidCallback onOpenLinkMemo;
  final VoidCallback onCaptureCamera;
  final VoidCallback onOpenDraftBox;
  final VoidCallback onRequestLocation;
  final VoidCallback onOpenVisibilityMenu;
  final VoidCallback onCutParagraphs;

  @override
  Widget build(BuildContext context) {
    final actions = <MemoComposeToolbarActionSpec>[
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.bold,
        enabled: !busy,
        onPressed: composer.toggleBold,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.italic,
        enabled: !busy,
        onPressed: composer.toggleItalic,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.strikethrough,
        enabled: !busy,
        onPressed: composer.toggleStrikethrough,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.inlineCode,
        enabled: !busy,
        onPressed: composer.toggleInlineCode,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.list,
        enabled: !busy,
        onPressed: composer.toggleUnorderedList,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.orderedList,
        enabled: !busy,
        onPressed: composer.toggleOrderedList,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.taskList,
        enabled: !busy,
        onPressed: composer.toggleTaskList,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.quote,
        enabled: !busy,
        onPressed: composer.toggleQuote,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.heading1,
        enabled: !busy,
        onPressed: composer.toggleHeading1,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.heading2,
        enabled: !busy,
        onPressed: composer.toggleHeading2,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.heading3,
        enabled: !busy,
        onPressed: composer.toggleHeading3,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.underline,
        enabled: !busy,
        onPressed: composer.toggleUnderline,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.highlight,
        enabled: !busy,
        onPressed: composer.toggleHighlight,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.divider,
        enabled: !busy,
        onPressed: composer.insertDivider,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.codeBlock,
        enabled: !busy,
        onPressed: composer.insertCodeBlock,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.inlineMath,
        enabled: !busy,
        onPressed: composer.insertInlineMath,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.blockMath,
        enabled: !busy,
        onPressed: composer.insertBlockMath,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.table,
        enabled: !busy,
        onPressed: composer.insertTableTemplate,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.cutParagraph,
        enabled: !busy,
        onPressed: onCutParagraphs,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.undo,
        enabled: !busy && composer.canUndo,
        onPressed: composer.undo,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.redo,
        enabled: !busy && composer.canRedo,
        onPressed: composer.redo,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.tag,
        buttonKey: tagMenuKey,
        enabled: !busy,
        onPressed: () =>
            composer.startTagAutocomplete(requestFocus: focusNode.requestFocus),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.template,
        buttonKey: templateMenuKey,
        enabled: !busy && availableTemplates.isNotEmpty,
        onPressed: onOpenTemplateMenu,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.attachment,
        enabled: !busy,
        onPressed: onPickFile,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.gallery,
        enabled: !busy,
        onPressed: onPickGallery,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.todo,
        buttonKey: todoMenuKey,
        enabled: !busy,
        onPressed: onOpenTodoMenu,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.link,
        enabled: !busy,
        onPressed: onOpenLinkMemo,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.camera,
        enabled: !busy,
        onPressed: onCaptureCamera,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.location,
        icon: locating ? Icons.my_location : null,
        enabled: !busy && !locating,
        onPressed: onRequestLocation,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.draftBox,
        enabled: !busy,
        onPressed: onOpenDraftBox,
      ),
      ...preferences.customButtons.map(
        (button) => MemoComposeToolbarActionSpec.custom(
          button: button,
          enabled: !busy,
          onPressed: () => composer.insertText(button.insertContent),
        ),
      ),
    ];

    return MemoComposeToolbar(
      isDark: isDark,
      preferences: preferences,
      actions: actions,
      visibilityMessage: context.t.strings.legacy.msg_visibility_2(
        visibilityLabel: visibilityLabel,
      ),
      visibilityIcon: visibilityIcon,
      visibilityColor: visibilityColor,
      visibilityButtonKey: visibilityMenuKey,
      onVisibilityPressed: busy ? null : onOpenVisibilityMenu,
    );
  }
}

class _InlineAttachmentPreview extends StatelessWidget {
  const _InlineAttachmentPreview({
    required this.attachments,
    required this.busy,
    required this.isDark,
    required this.onRemoveAttachment,
    required this.onOpenAttachment,
  });

  final List<MemoComposerPendingAttachment> attachments;
  final bool busy;
  final bool isDark;
  final ValueChanged<String> onRemoveAttachment;
  final ValueChanged<MemoComposerPendingAttachment> onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    const tileSize = 62.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: tileSize,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < attachments.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _InlineAttachmentTile(
                  attachment: attachments[i],
                  busy: busy,
                  isDark: isDark,
                  size: tileSize,
                  onRemove: onRemoveAttachment,
                  onOpenAttachment: onOpenAttachment,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineAttachmentTile extends StatelessWidget {
  const _InlineAttachmentTile({
    required this.attachment,
    required this.busy,
    required this.isDark,
    required this.size,
    required this.onRemove,
    required this.onOpenAttachment,
  });

  final MemoComposerPendingAttachment attachment;
  final bool busy;
  final bool isDark;
  final double size;
  final ValueChanged<String> onRemove;
  final ValueChanged<MemoComposerPendingAttachment> onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final surfaceColor = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final iconColor =
        (isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight)
            .withValues(alpha: 0.6);
    final removeBg = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.5);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.35 : 0.12);
    final tileBorderColor = borderColor.withValues(alpha: 0.7);
    final tileRadius = BorderRadius.circular(14);
    final isImage = _isInlineImageMimeType(attachment.mimeType);
    final isVideo = _isInlineVideoMimeType(attachment.mimeType);
    final file = _resolveInlinePendingAttachmentFile(attachment);
    final cacheExtent = resolveThumbnailCacheExtent(
      size,
      MediaQuery.devicePixelRatioOf(context),
    );

    Widget content;
    if (isImage && file != null) {
      content = ImagePreviewTile(
        item: ImagePreviewItem(
          id: 'inline-pending:${attachment.uid}',
          title: attachment.filename,
          mimeType: attachment.mimeType,
          localFile: file,
        ),
        width: double.infinity,
        height: double.infinity,
        borderRadius: 14,
        backgroundColor: surfaceColor,
        borderColor: tileBorderColor,
        placeholderColor: surfaceColor,
        iconColor: iconColor,
        cacheWidth: cacheExtent,
        cacheHeight: cacheExtent,
        logScope: 'inline_compose_pending_tile',
      );
    } else if (isVideo && file != null) {
      final entry = MemoVideoEntry(
        id: attachment.uid,
        title: attachment.filename.isNotEmpty ? attachment.filename : 'video',
        mimeType: attachment.mimeType,
        size: attachment.size,
        localFile: file,
        videoUrl: null,
        headers: null,
      );
      content = AttachmentVideoThumbnail(
        entry: entry,
        width: size,
        height: size,
        borderRadius: 14,
        fit: BoxFit.cover,
        showPlayIcon: false,
      );
    } else {
      content = _InlineAttachmentFallback(
        iconColor: iconColor,
        surfaceColor: surfaceColor,
        isImage: isImage,
        isVideo: isVideo,
      );
    }

    final tile = isImage && file != null
        ? SizedBox(
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: tileRadius,
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: tileRadius,
                child: Stack(fit: StackFit.expand, children: [content]),
              ),
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: tileRadius,
              border: Border.all(color: tileBorderColor),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(borderRadius: tileRadius, child: content),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          key: ValueKey<String>('inline-attachment-${attachment.uid}'),
          onTap: (isImage && file != null)
              ? () => onOpenAttachment(attachment)
              : null,
          child: tile,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            key: ValueKey<String>('inline-attachment-remove-${attachment.uid}'),
            onTap: busy ? null : () => onRemove(attachment.uid),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: removeBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineAttachmentFallback extends StatelessWidget {
  const _InlineAttachmentFallback({
    required this.iconColor,
    required this.surfaceColor,
    required this.isImage,
    this.isVideo = false,
  });

  final Color iconColor;
  final Color surfaceColor;
  final bool isImage;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: surfaceColor,
      alignment: Alignment.center,
      child: Icon(
        isImage
            ? Icons.image_outlined
            : (isVideo
                  ? Icons.videocam_outlined
                  : Icons.insert_drive_file_outlined),
        size: 22,
        color: iconColor,
      ),
    );
  }
}

bool _isInlineImageMimeType(String mimeType) {
  return mimeType.toLowerCase().startsWith('image/');
}

bool _isInlineVideoMimeType(String mimeType) {
  return mimeType.toLowerCase().startsWith('video/');
}

File? _resolveInlinePendingAttachmentFile(
  MemoComposerPendingAttachment attachment,
) {
  final path = attachment.filePath.trim();
  if (path.isEmpty) return null;
  final file = File(path);
  return file.existsSync() ? file : null;
}
