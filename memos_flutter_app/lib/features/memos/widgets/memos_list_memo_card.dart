import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_localization.dart';
import '../../../core/attachment_toast.dart';
import '../../../core/location_launcher.dart';
import '../../../core/memo_content_diagnostics.dart';
import '../../../core/memoflow_palette.dart';
import '../../../data/models/app_preferences.dart';
import '../../../data/models/location_settings.dart';
import '../../../data/models/local_memo.dart';
import '../../../data/logs/log_manager.dart';
import '../../../state/memos/memos_providers.dart';
import '../../../state/memos/memos_list_providers.dart';
import '../../../state/tags/tag_color_lookup.dart';
import '../../image_preview/image_preview_launcher.dart';
import '../memo_detail_screen.dart';
import '../memo_card_preview.dart';
import '../memo_hero_flight.dart';
import '../memo_image_grid.dart';
import '../memo_location_line.dart';
import '../memo_markdown.dart';
import '../memo_media_grid.dart';
import 'audio_row.dart';
import 'floating_collapse_button.dart';
import '../../../i18n/strings.g.dart';

enum MemoSyncStatus { none, pending, failed }

class _LruCache<K, V> {
  _LruCache({required int capacity}) : _capacity = capacity;

  final int _capacity;
  final _map = <K, V>{};

  V? get(K key) {
    final value = _map.remove(key);
    if (value == null) return null;
    _map[key] = value;
    return value;
  }

  void set(K key, V value) {
    if (_capacity <= 0) return;
    _map.remove(key);
    _map[key] = value;
    if (_map.length > _capacity) {
      _map.remove(_map.keys.first);
    }
  }

  void removeWhere(bool Function(K key) test) {
    final keys = _map.keys.where(test).toList(growable: false);
    for (final key in keys) {
      _map.remove(key);
    }
  }
}

class _MemoRenderCacheEntry {
  const _MemoRenderCacheEntry({
    required this.previewText,
    required this.preview,
    required this.taskStats,
  });

  final String previewText;
  final MemoCardPreviewResult preview;
  final TaskStats taskStats;
}

final _memoRenderCache = _LruCache<String, _MemoRenderCacheEntry>(
  capacity: 120,
);
final Set<String> _memoDeleteCardLogKeys = <String>{};

void _logMemoDeleteCardOnce(
  String message,
  LocalMemo memo, {
  Map<String, Object?> context = const <String, Object?>{},
}) {
  final key = '$message|${memo.uid}';
  if (!_memoDeleteCardLogKeys.add(key)) return;
  LogManager.instance.info(
    message,
    context: <String, Object?>{
      ...buildMemoContentDiagnostics(memo.content, memoUid: memo.uid),
      'attachmentCount': memo.attachments.length,
      ...context,
    },
  );
}

String _memoRenderCacheKey(
  LocalMemo memo, {
  required bool collapseLongContent,
  required bool collapseReferences,
  required AppLanguage language,
}) {
  return '${memo.uid}|'
      '${memo.contentFingerprint}|'
      '${collapseLongContent ? 1 : 0}|'
      '${collapseReferences ? 1 : 0}|'
      '${language.name}';
}

void invalidateMemoRenderCacheForUid(String memoUid) {
  final trimmed = memoUid.trim();
  if (trimmed.isEmpty) return;
  _memoRenderCache.removeWhere((key) => key.startsWith('$trimmed|'));
}

enum MemoCardAction {
  togglePinned,
  edit,
  history,
  reminder,
  addToCollection,
  archive,
  restore,
  delete,
}

Rect? globalRectForKey(GlobalKey key) {
  final context = key.currentContext;
  if (context == null) return null;
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

class MemoFloatingCollapseCandidate {
  const MemoFloatingCollapseCandidate({
    required this.memoUid,
    required this.visibleHeight,
  });

  final String memoUid;
  final double visibleHeight;
}

class MemoListCard extends StatefulWidget {
  const MemoListCard({
    super.key,
    required this.memo,
    this.heroTag,
    this.debugRemoving = false,
    required this.dateText,
    required this.reminderText,
    required this.tagColors,
    required this.initiallyExpanded,
    required this.highlightQuery,
    required this.collapseLongContent,
    required this.collapseReferences,
    required this.isAudioPlaying,
    required this.isAudioLoading,
    required this.audioPositionListenable,
    required this.audioDurationListenable,
    required this.imageEntries,
    required this.mediaEntries,
    this.contentTextOverride,
    this.contentHeader,
    this.useExpandedArticleBody = false,
    this.baseUrl,
    this.authHeader,
    this.rebaseAbsoluteFileUrlForV024 = false,
    this.attachAuthForSameOriginAbsolute = false,
    required this.locationProvider,
    required this.onAudioSeek,
    required this.onAudioTap,
    required this.syncStatus,
    this.onSyncStatusTap,
    required this.onToggleTask,
    required this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.onFloatingStateChanged,
    required this.onAction,
  });

  final LocalMemo memo;
  final Object? heroTag;
  final bool debugRemoving;
  final String dateText;
  final String? reminderText;
  final TagColorLookup tagColors;
  final bool initiallyExpanded;
  final String? highlightQuery;
  final bool collapseLongContent;
  final bool collapseReferences;
  final bool isAudioPlaying;
  final bool isAudioLoading;
  final ValueListenable<Duration>? audioPositionListenable;
  final ValueListenable<Duration?>? audioDurationListenable;
  final List<MemoImageEntry> imageEntries;
  final List<MemoMediaEntry> mediaEntries;
  final String? contentTextOverride;
  final Widget? contentHeader;
  final bool useExpandedArticleBody;
  final Uri? baseUrl;
  final String? authHeader;
  final bool rebaseAbsoluteFileUrlForV024;
  final bool attachAuthForSameOriginAbsolute;
  final LocationServiceProvider locationProvider;
  final ValueChanged<Duration>? onAudioSeek;
  final VoidCallback? onAudioTap;
  final MemoSyncStatus syncStatus;
  final VoidCallback? onSyncStatusTap;
  final ValueChanged<int> onToggleTask;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onFloatingStateChanged;
  final ValueChanged<MemoCardAction> onAction;

  @override
  State<MemoListCard> createState() => MemoListCardState();
}

class MemoListCardState extends State<MemoListCard> {
  late bool _expanded;
  final _cardKey = GlobalKey();
  final _toggleButtonKey = GlobalKey();
  bool _showToggle = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        widget.debugRemoving) {
      _logMemoDeleteCardOnce(
        'Memo delete card state init',
        widget.memo,
        context: <String, Object?>{
          'initiallyExpanded': widget.initiallyExpanded,
        },
      );
    }
  }

  void _notifyFloatingStateChanged() {
    widget.onFloatingStateChanged?.call();
  }

  void collapseFromFloating() {
    if (!_expanded) return;
    setState(() => _expanded = false);
    _notifyFloatingStateChanged();
  }

  MemoFloatingCollapseCandidate? resolveFloatingCollapseCandidate(
    Rect viewportRect,
  ) {
    if (!_expanded || !_showToggle) return null;
    final cardRect = globalRectForKey(_cardKey);
    final toggleRect = globalRectForKey(_toggleButtonKey);
    if (cardRect == null || toggleRect == null) return null;
    final visibleHeight = math.max(
      0.0,
      math.min(cardRect.bottom, viewportRect.bottom) -
          math.max(cardRect.top, viewportRect.top),
    );
    if (visibleHeight <= 0) return null;
    if (!shouldShowFloatingCollapseForToggle(
      viewportRect: viewportRect,
      toggleRect: toggleRect,
    )) {
      return null;
    }
    return MemoFloatingCollapseCandidate(
      memoUid: widget.memo.uid,
      visibleHeight: visibleHeight,
    );
  }

  @override
  void didUpdateWidget(covariant MemoListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        (oldWidget.debugRemoving || widget.debugRemoving)) {
      _logMemoDeleteCardOnce(
        'Memo delete card state didUpdateWidget',
        widget.memo,
        context: <String, Object?>{
          'oldMemoUidChanged': oldWidget.memo.uid != widget.memo.uid,
          'oldInitiallyExpanded': oldWidget.initiallyExpanded,
          'newInitiallyExpanded': widget.initiallyExpanded,
          'oldDebugRemoving': oldWidget.debugRemoving,
          'newDebugRemoving': widget.debugRemoving,
        },
      );
    }
    if (oldWidget.memo.uid != widget.memo.uid) {
      _expanded = widget.initiallyExpanded;
      _notifyFloatingStateChanged();
      return;
    }
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
      _notifyFloatingStateChanged();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        widget.debugRemoving) {
      _logMemoDeleteCardOnce(
        'Memo delete card state dispose',
        widget.memo,
        context: <String, Object?>{
          'expandedAtDispose': _expanded,
          'showToggleAtDispose': _showToggle,
        },
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memo = widget.memo;
    final dateText = widget.dateText;
    final reminderText = widget.reminderText;
    final collapseLongContent = widget.collapseLongContent;
    final collapseReferences = widget.collapseReferences;
    final onToggleTask = widget.onToggleTask;
    final onTap = widget.onTap;
    final onAction = widget.onAction;
    final onAudioTap = widget.onAudioTap;
    final audioPlaying = widget.isAudioPlaying;
    final audioLoading = widget.isAudioLoading;
    final audioPositionListenable = widget.audioPositionListenable;
    final audioDurationListenable = widget.audioDurationListenable;
    final onAudioSeek = widget.onAudioSeek;
    final mediaEntries = widget.mediaEntries;
    final syncStatus = widget.syncStatus;
    final onSyncStatusTap = widget.onSyncStatusTap;
    final onDoubleTap = widget.onDoubleTap;
    final onLongPress = widget.onLongPress;

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
    final isPinned = memo.pinned;
    final pinColor = MemoFlowPalette.primary;
    final pinBorderColor = pinColor.withValues(alpha: isDark ? 0.5 : 0.4);
    final pinTint = pinColor.withValues(alpha: isDark ? 0.18 : 0.08);
    final cardSurface = isPinned
        ? Color.alphaBlend(pinTint, cardColor)
        : cardColor;
    final cardBorderColor = isPinned ? pinBorderColor : borderColor;
    final menuColor = isDark
        ? const Color(0xFF2B2523)
        : const Color(0xFFF6E7E3);
    final deleteColor = isDark
        ? const Color(0xFFFF7A7A)
        : const Color(0xFFE05656);
    final isArchived = widget.memo.state == 'ARCHIVED';
    final pendingColor = textMain.withValues(alpha: isDark ? 0.45 : 0.35);
    final attachmentColor = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final showSyncStatus = syncStatus != MemoSyncStatus.none;
    final headerMinHeight = 32.0;
    final syncIcon = syncStatus == MemoSyncStatus.failed
        ? Icons.error_outline
        : Icons.cloud_upload_outlined;
    final syncColor = syncStatus == MemoSyncStatus.failed
        ? deleteColor
        : pendingColor;
    final pinnedChip = isPinned
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pinColor.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: pinBorderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.push_pin, size: 12, color: pinColor),
                const SizedBox(width: 4),
                Text(
                  context.t.strings.legacy.msg_pinned,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: pinColor,
                  ),
                ),
              ],
            ),
          )
        : null;

    final audio = memo.attachments
        .where((a) => a.type.startsWith('audio'))
        .toList(growable: false);
    final hasAudio = audio.isNotEmpty;
    final nonMediaAttachments = filterNonMediaAttachments(memo.attachments);
    final attachmentLines = attachmentNameLines(nonMediaAttachments);
    final attachmentCount = nonMediaAttachments.length;
    final contentText = widget.contentTextOverride ?? memo.content;
    final language = context.appLanguage;
    final normalizedHighlightQuery = widget.highlightQuery?.trim();
    final highlightQuery =
        normalizedHighlightQuery == null || normalizedHighlightQuery.isEmpty
        ? null
        : normalizedHighlightQuery;
    final highlightKey = highlightQuery?.toLowerCase() ?? '';
    final cacheKeyBase = _memoRenderCacheKey(
      memo,
      collapseLongContent: collapseLongContent,
      collapseReferences: collapseReferences,
      language: language,
    );
    final cacheKey = widget.contentTextOverride == null
        ? cacheKeyBase
        : '$cacheKeyBase|clip=${contentText.hashCode}';
    final cached = _memoRenderCache.get(cacheKey);
    final previewText =
        cached?.previewText ??
        buildMemoCardPreviewText(
          contentText,
          collapseReferences: false,
          language: language,
        );
    final preview =
        cached?.preview ??
        truncateMemoCardPreview(
          previewText,
          collapseLongContent: collapseLongContent,
        );
    final taskStats =
        cached?.taskStats ??
        countTaskStats(contentText, skipQuotedLines: collapseReferences);
    if (cached == null) {
      _memoRenderCache.set(
        cacheKey,
        _MemoRenderCacheEntry(
          previewText: previewText,
          preview: preview,
          taskStats: taskStats,
        ),
      );
    }
    final showToggle = preview.truncated;
    _showToggle = showToggle;
    final showCollapsed = showToggle && !_expanded;
    final renderExpandedArticleBody =
        widget.useExpandedArticleBody && _expanded;
    final displayText = renderExpandedArticleBody ? contentText : previewText;
    final markdownCacheKey = '$cacheKey|md|searchhl=v2|hl=$highlightKey';
    final showProgress = !hasAudio && taskStats.total > 0;
    final progress = showProgress ? taskStats.checked / taskStats.total : 0.0;
    final audioDurationText = _parseVoiceDuration(contentText) ?? '00:00';
    final audioDurationFallback = _parseVoiceDurationValue(contentText);
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        widget.debugRemoving) {
      _logMemoDeleteCardOnce(
        'Memo delete card build snapshot',
        memo,
        context: <String, Object?>{
          'mediaEntryCount': mediaEntries.length,
          'audioAttachmentCount': audio.length,
          'nonMediaAttachmentCount': attachmentCount,
          'attachmentBadgeVisible': attachmentCount > 0,
          'hasAudioRow': hasAudio,
          'hasMediaGrid': mediaEntries.isNotEmpty,
          'showToggle': showToggle,
          'expanded': _expanded,
          'showCollapsed': showCollapsed,
          'showSyncStatus': showSyncStatus,
          'hasReminder': reminderText != null,
          'hasLocation': memo.location != null,
          'relationCount': memo.relationCount,
          'heroEnabled': true,
          'hasDoubleTapHandler': onDoubleTap != null,
          'hasLongPressHandler': onLongPress != null,
          'hasOnTapHandler': true,
          'markdownCacheKeyFingerprint': markdownCacheKey.hashCode.toString(),
        },
      );
      final removingPreview = preview.text.trim();
      return Container(
        key: _cardKey,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dateText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: textMain.withValues(alpha: isDark ? 0.4 : 0.5),
              ),
            ),
            if (removingPreview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                removingPreview,
                maxLines: kMemoCardPreviewMaxLines + 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: textMain.withValues(alpha: 0.92),
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget buildMediaGrid() {
      if (mediaEntries.isEmpty) return const SizedBox.shrink();
      final previewBorder = borderColor.withValues(alpha: 0.65);
      final previewBg = isDark
          ? MemoFlowPalette.audioSurfaceDark.withValues(alpha: 0.6)
          : MemoFlowPalette.audioSurfaceLight;
      final maxHeight = MediaQuery.of(context).size.height * 0.4;
      return MemoMediaGrid(
        entries: mediaEntries,
        columns: 3,
        maxCount: 9,
        maxHeight: maxHeight,
        preserveSquareTilesWhenHeightLimited: Platform.isWindows,
        radius: 0,
        spacing: 4,
        borderColor: previewBorder,
        backgroundColor: previewBg,
        textColor: textMain,
        enableDownload: true,
      );
    }

    String formatDuration(Duration value) {
      final totalSeconds = value.inSeconds;
      final hh = totalSeconds ~/ 3600;
      final mm = (totalSeconds % 3600) ~/ 60;
      final ss = totalSeconds % 60;
      if (hh <= 0) {
        return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
      }
      return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    }

    Widget buildAudioRow(Duration position, Duration? duration) {
      final effectiveDuration = duration ?? audioDurationFallback;
      final clampedPosition =
          effectiveDuration != null && position > effectiveDuration
          ? effectiveDuration
          : position;
      final totalText = effectiveDuration != null
          ? formatDuration(effectiveDuration)
          : audioDurationText;
      final showPosition = clampedPosition > Duration.zero || audioPlaying;
      final displayText = effectiveDuration != null && showPosition
          ? '${formatDuration(clampedPosition)} / $totalText'
          : (showPosition ? formatDuration(clampedPosition) : totalText);

      return AudioRow(
        durationText: displayText,
        isDark: isDark,
        playing: audioPlaying,
        loading: audioLoading,
        position: clampedPosition,
        duration: duration,
        durationFallback: audioDurationFallback,
        onSeek: onAudioSeek,
        onTap: onAudioTap,
      );
    }

    Widget audioRow = buildAudioRow(Duration.zero, null);
    if (audioPositionListenable != null && audioDurationListenable != null) {
      audioRow = ValueListenableBuilder<Duration>(
        valueListenable: audioPositionListenable,
        builder: (context, position, _) {
          return ValueListenableBuilder<Duration?>(
            valueListenable: audioDurationListenable,
            builder: (context, duration, _) {
              return buildAudioRow(position, duration);
            },
          );
        },
      );
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.contentHeader != null) ...[
          widget.contentHeader!,
          const SizedBox(height: 12),
        ],
        if (showProgress) ...[
          TaskProgressBar(
            progress: progress,
            isDark: isDark,
            total: taskStats.total,
            checked: taskStats.checked,
          ),
          const SizedBox(height: 2),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MemoMarkdown(
              cacheKey: markdownCacheKey,
              data: displayText,
              highlightQuery: highlightQuery,
              maxLines: showCollapsed ? 6 : null,
              textStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textMain),
              blockSpacing: renderExpandedArticleBody ? 8 : 4,
              normalizeHeadings: true,
              renderImages: renderExpandedArticleBody,
              tagColors: widget.tagColors,
              baseUrl: widget.baseUrl,
              authHeader: widget.authHeader,
              rebaseAbsoluteFileUrlForV024:
                  widget.rebaseAbsoluteFileUrlForV024,
              attachAuthForSameOriginAbsolute:
                  widget.attachAuthForSameOriginAbsolute,
              imagePreviewItems: widget.imageEntries
                  .map((entry) => entry.toImagePreviewItem())
                  .toList(growable: false),
              onOpenImagePreview: (request) =>
                  ImagePreviewLauncher.open(context, request),
              onToggleTask: (request) => onToggleTask(request.taskIndex),
            ),
            if (showToggle) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: _toggleButtonKey,
                  onPressed: () {
                    setState(() => _expanded = !_expanded);
                    _notifyFloatingStateChanged();
                  },
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
            if (mediaEntries.isNotEmpty && !renderExpandedArticleBody) ...[
              const SizedBox(height: 2),
              buildMediaGrid(),
            ],
            if (hasAudio) ...[const SizedBox(height: 2), audioRow],
            if (attachmentCount > 0) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Builder(
                  builder: (context) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () =>
                            showAttachmentNamesToast(context, attachmentLines),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attach_file,
                                size: 14,
                                color: attachmentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                attachmentCount.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: attachmentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        MemoRelationsSection(
          memoUid: memo.uid,
          initialCount: memo.relationCount,
        ),
      ],
    );

    if (onDoubleTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: onDoubleTap,
        child: content,
      );
    }

    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          key: _cardKey,
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
              Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: headerMinHeight,
                        child: Row(
                          children: [
                            if (pinnedChip != null) ...[
                              pinnedChip,
                              const SizedBox(width: 8),
                            ],
                            Text(
                              dateText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: textMain.withValues(
                                  alpha: isDark ? 0.4 : 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (memo.location != null) ...[
                        const SizedBox(height: 2),
                        MemoLocationLine(
                          location: memo.location!,
                          textColor: textMain.withValues(
                            alpha: isDark ? 0.4 : 0.5,
                          ),
                          onTap: () => openMemoLocation(
                            context,
                            memo.location!,
                            memoUid: memo.uid,
                            provider: widget.locationProvider,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (reminderText != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_active_outlined,
                                    size: 14,
                                    color: MemoFlowPalette.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    reminderText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: MemoFlowPalette.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (showSyncStatus)
                            IconButton(
                              onPressed: onSyncStatusTap,
                              icon: Icon(syncIcon, size: 16, color: syncColor),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              splashRadius: 16,
                            ),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: Center(
                              child: PopupMenuButton<MemoCardAction>(
                                tooltip: context.t.strings.legacy.msg_more,
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.more_horiz,
                                  size: 20,
                                  color: textMain.withValues(
                                    alpha: isDark ? 0.4 : 0.5,
                                  ),
                                ),
                                onSelected: onAction,
                                color: menuColor,
                                surfaceTintColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                itemBuilder: (context) => isArchived
                                    ? [
                                        PopupMenuItem(
                                          value: MemoCardAction.history,
                                          child: Text(
                                            context
                                                .t
                                                .strings
                                                .settings
                                                .preferences
                                                .history,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: MemoCardAction.restore,
                                          child: Text(
                                            context
                                                .t
                                                .strings
                                                .legacy
                                                .msg_restore,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: MemoCardAction.delete,
                                          child: Text(
                                            context.t.strings.legacy.msg_delete,
                                            style: TextStyle(
                                              color: deleteColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ]
                                    : [
                                        PopupMenuItem(
                                          value: MemoCardAction.togglePinned,
                                          child: Text(
                                            memo.pinned
                                                ? context
                                                      .t
                                                      .strings
                                                      .legacy
                                                      .msg_unpin
                                                : context
                                                      .t
                                                      .strings
                                                      .legacy
                                                      .msg_pin,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: MemoCardAction.edit,
                                          child: Text(
                                            context.t.strings.legacy.msg_edit,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: MemoCardAction.history,
                                          child: Text(
                                            context
                                                .t
                                                .strings
                                                .settings
                                                .preferences
                                                .history,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: MemoCardAction.reminder,
                                          child: Text(
                                            context
                                                .t
                                                .strings
                                                .legacy
                                                .msg_reminder,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: MemoCardAction.addToCollection,
                                          child: Text(
                                            context
                                                .t
                                                .strings
                                                .collections
                                                .addToCollection,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: MemoCardAction.archive,
                                          child: Text(
                                            context
                                                .t
                                                .strings
                                                .legacy
                                                .msg_archive,
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        PopupMenuItem(
                                          value: MemoCardAction.delete,
                                          child: Text(
                                            context.t.strings.legacy.msg_delete,
                                            style: TextStyle(
                                              color: deleteColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 0),
              content,
            ],
          ),
        ),
      ),
    );
    final heroTag = widget.heroTag;
    if (heroTag == null) {
      return card;
    }
    return Hero(
      tag: heroTag,
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end),
      flightShuttleBuilder: memoHeroFlightShuttleBuilder(isPinned: memo.pinned),
      child: card,
    );
  }

  static String? _parseVoiceDuration(String content) {
    final value = _parseVoiceDurationValue(content);
    if (value == null) return null;
    final totalSeconds = value.inSeconds;
    final hh = totalSeconds ~/ 3600;
    final mm = (totalSeconds % 3600) ~/ 60;
    final ss = totalSeconds % 60;
    if (hh <= 0) {
      return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    }
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }

  static Duration? _parseVoiceDurationValue(String content) {
    final linePattern = RegExp(r'^[-*+•]?\s*', unicode: true);
    final valuePattern = RegExp(
      r'^(时长|Duration)\s*[:：]?\s*(\d{1,2}):(\d{1,2}):(\d{1,2})$',
      caseSensitive: false,
      unicode: true,
    );

    for (final rawLine in content.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;
      final line = trimmed.replaceFirst(linePattern, '');
      final m = valuePattern.firstMatch(line);
      if (m == null) continue;
      final hh = int.tryParse(m.group(2) ?? '') ?? 0;
      final mm = int.tryParse(m.group(3) ?? '') ?? 0;
      final ss = int.tryParse(m.group(4) ?? '') ?? 0;
      if (hh == 0 && mm == 0 && ss == 0) return null;
      return Duration(hours: hh, minutes: mm, seconds: ss);
    }

    return null;
  }
}

class MemoRelationsSection extends ConsumerStatefulWidget {
  const MemoRelationsSection({
    super.key,
    required this.memoUid,
    required this.initialCount,
  });

  final String memoUid;
  final int initialCount;

  @override
  ConsumerState<MemoRelationsSection> createState() =>
      MemoRelationsSectionState();
}

class MemoRelationsSectionState extends ConsumerState<MemoRelationsSection> {
  bool _expanded = false;
  int _cachedTotal = 0;

  @override
  void initState() {
    super.initState();
    _cachedTotal = widget.initialCount;
  }

  @override
  void didUpdateWidget(covariant MemoRelationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCount != oldWidget.initialCount) {
      _cachedTotal = widget.initialCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded && _cachedTotal == 0) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final bg = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);

    final summaryRow = RelationSummaryRow(
      borderColor: borderColor,
      bg: bg,
      textMain: textMain,
      textMuted: textMuted,
      expanded: _expanded,
      countText: _cachedTotal.toString(),
      onTap: () => setState(() => _expanded = !_expanded),
      boxed: false,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            summaryRow,
            if (_expanded) const SizedBox(height: 2),
            if (_expanded) _buildExpanded(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(BuildContext context, bool isDark) {
    final relationsAsync = ref.watch(memoRelationsProvider(widget.memoUid));
    return relationsAsync.when(
      data: (relations) {
        final currentName = 'memos/${widget.memoUid}';
        final referencing = <RelationItem>[];
        final referencedBy = <RelationItem>[];
        final seenReferencing = <String>{};
        final seenReferencedBy = <String>{};

        for (final relation in relations) {
          final type = relation.type.trim().toUpperCase();
          if (type != 'REFERENCE') {
            continue;
          }
          final memoName = relation.memo.name.trim();
          final relatedName = relation.relatedMemo.name.trim();

          if (memoName == currentName && relatedName.isNotEmpty) {
            if (seenReferencing.add(relatedName)) {
              referencing.add(
                RelationItem(
                  name: relatedName,
                  snippet: relation.relatedMemo.snippet,
                ),
              );
            }
            continue;
          }
          if (relatedName == currentName && memoName.isNotEmpty) {
            if (seenReferencedBy.add(memoName)) {
              referencedBy.add(
                RelationItem(name: memoName, snippet: relation.memo.snippet),
              );
            }
          }
        }

        final total = referencing.length + referencedBy.length;
        _maybeCacheTotal(total);

        if (total == 0) {
          return _buildEmptyState(context, isDark);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (referencing.isNotEmpty)
              RelationGroup(
                title: context.t.strings.legacy.msg_references,
                items: referencing,
                isDark: isDark,
                showHeader: false,
                onTap: (item) => _openMemo(context, ref, item.name),
                boxed: false,
              ),
            if (referencing.isNotEmpty && referencedBy.isNotEmpty)
              const SizedBox(height: 2),
            if (referencedBy.isNotEmpty)
              RelationGroup(
                title: context.t.strings.legacy.msg_referenced,
                items: referencedBy,
                isDark: isDark,
                showHeader: false,
                onTap: (item) => _openMemo(context, ref, item.name),
                boxed: false,
              ),
          ],
        );
      },
      loading: () => _buildLoading(context),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  void _maybeCacheTotal(int total) {
    if (_cachedTotal == total) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _cachedTotal = total);
    });
  }

  Widget _buildLoading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.link, size: 14, color: textMuted),
          const SizedBox(width: 6),
          Text(
            context.t.strings.legacy.msg_loading_links,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
          const Spacer(),
          SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.link_off, size: 14, color: textMuted),
          const SizedBox(width: 6),
          Text(
            context.t.strings.legacy.msg_no_links,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMemo(
    BuildContext context,
    WidgetRef ref,
    String rawName,
  ) async {
    final uid = _normalizeMemoUid(rawName);
    if (uid.isEmpty || uid == widget.memoUid) return;

    final result = await ref
        .read(memosListControllerProvider)
        .resolveMemoForOpen(uid: uid);
    final error = result.error;
    if (error != null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_failed_load_4(e: error)),
        ),
      );
      return;
    }

    if (result.isNotFound) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_memo_not_found_locally),
        ),
      );
      return;
    }

    final memo = result.memo!;
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoDetailScreen(initialMemo: memo),
      ),
    );
  }

  String _normalizeMemoUid(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('memos/')) return trimmed.substring('memos/'.length);
    return trimmed;
  }
}

class RelationSummaryRow extends StatelessWidget {
  const RelationSummaryRow({
    super.key,
    required this.borderColor,
    required this.bg,
    required this.textMain,
    required this.textMuted,
    required this.expanded,
    required this.countText,
    required this.onTap,
    this.boxed = true,
  });

  final Color borderColor;
  final Color bg;
  final Color textMain;
  final Color textMuted;
  final bool expanded;
  final String countText;
  final VoidCallback onTap;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final label = context.t.strings.legacy.msg_links;
    final decoration = boxed
        ? BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor.withValues(alpha: 0.7)),
          )
        : null;
    final padding = boxed
        ? const EdgeInsets.symmetric(horizontal: 12)
        : EdgeInsets.zero;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: padding,
          decoration: decoration,
          child: Row(
            children: [
              Icon(Icons.link, size: 14, color: textMuted),
              const SizedBox(width: 6),
              Text(
                '$label - $countText',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textMain,
                ),
              ),
              const Spacer(),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RelationGroup extends StatelessWidget {
  const RelationGroup({
    super.key,
    required this.title,
    required this.items,
    required this.isDark,
    this.showHeader = true,
    this.onTap,
    this.boxed = true,
  });

  final String title;
  final List<RelationItem> items;
  final bool isDark;
  final bool showHeader;
  final ValueChanged<RelationItem>? onTap;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final bg = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final headerColor = textMain.withValues(alpha: isDark ? 0.7 : 0.8);
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    final decoration = boxed
        ? BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor.withValues(alpha: 0.7)),
          )
        : null;
    final padding = boxed
        ? const EdgeInsets.fromLTRB(12, 10, 12, 12)
        : EdgeInsets.zero;
    return Container(
      padding: padding,
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                Icon(Icons.link, size: 14, color: headerColor),
                const SizedBox(width: 6),
                Text(
                  '$title (${items.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: headerColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          ...items.map((item) {
            final row = Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _shortMemoId(item.name),
                      style: TextStyle(fontSize: 10, color: headerColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _relationSnippet(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: textMain),
                    ),
                  ),
                ],
              ),
            );
            if (onTap == null) return row;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onTap!(item),
                child: row,
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _relationSnippet(RelationItem item) {
    final snippet = item.snippet.trim();
    if (snippet.isNotEmpty) return snippet;
    final name = item.name.trim();
    if (name.isNotEmpty) return name;
    return '';
  }

  static String _shortMemoId(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '--';
    final raw = trimmed.startsWith('memos/')
        ? trimmed.substring('memos/'.length)
        : trimmed;
    return raw.length <= 6 ? raw : raw.substring(0, 6);
  }
}

class RelationItem {
  const RelationItem({required this.name, required this.snippet});

  final String name;
  final String snippet;
}

class TaskProgressBar extends StatefulWidget {
  const TaskProgressBar({
    super.key,
    required this.progress,
    required this.isDark,
    required this.total,
    required this.checked,
  });

  final double progress;
  final bool isDark;
  final int total;
  final int checked;

  @override
  State<TaskProgressBar> createState() => TaskProgressBarState();
}

class TaskProgressBarState extends State<TaskProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    final targetValue = widget.progress.clamp(0.0, 1.0);
    _animation = Tween<double>(
      begin: targetValue,
      end: targetValue,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(TaskProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      final targetValue = widget.progress.clamp(0.0, 1.0);
      final currentValue = _animation.value;
      final difference = (targetValue - currentValue).abs();

      // 閺嶈宓佹潻娑樺瀹割喛绐涚拫鍐╂殻閸斻劎鏁鹃弮鍫曟毐閿涙艾妯婄捄婵婄Ш婢堆嶇礉閸斻劎鏁鹃弮鍫曟？鐡掑﹪鏆?
      final animationDuration = Duration(
        milliseconds: (400 + difference * 500).round(),
      );

      _controller.duration = animationDuration;

      _animation = Tween<double>(begin: currentValue, end: targetValue).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );

      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final textColor = widget.isDark ? Colors.white70 : Colors.black54;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final percentage = (_animation.value * 100).round();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${context.t.strings.legacy.msg_progress} (${widget.checked}/${widget.total})',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '$percentage%',
                    key: ValueKey(percentage),
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _animation.value,
                minHeight: 8,
                backgroundColor: bg,
                valueColor: AlwaysStoppedAnimation(MemoFlowPalette.primary),
              ),
            ),
          ],
        );
      },
    );
  }
}
