import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/memo_content_diagnostics.dart';
import '../../../core/url.dart';
import '../../../data/models/app_preferences.dart';
import '../../../data/models/local_memo.dart';
import '../../../state/memos/memos_list_providers.dart';
import '../../../state/memos/memos_providers.dart';
import '../../../state/settings/location_settings_provider.dart';
import '../../../state/settings/reminder_settings_provider.dart';
import '../../../state/system/logging_provider.dart';
import '../../../state/system/reminder_providers.dart';
import '../../../state/system/reminder_utils.dart';
import '../../../state/system/session_provider.dart';
import '../../../state/tags/tag_color_lookup.dart';
import '../memo_image_grid.dart';
import '../memo_media_grid.dart';
import '../memo_video_grid.dart';
import 'memos_list_memo_card.dart';

final DateFormat _memoDateFormatter = DateFormat('yyyy-MM-dd HH:mm');
final _memoMediaEntriesCache = _LruCache<String, _MemoMediaEntriesCacheEntry>(
  capacity: 120,
);

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
}

class _MemoMediaEntriesCacheEntry {
  const _MemoMediaEntriesCacheEntry({
    required this.imageEntries,
    required this.videoEntries,
    required this.mediaEntries,
  });

  final List<MemoImageEntry> imageEntries;
  final List<MemoVideoEntry> videoEntries;
  final List<MemoMediaEntry> mediaEntries;
}

String _memoMediaEntriesCacheKey({
  required LocalMemo memo,
  required Uri? baseUrl,
  required String? authHeader,
  required bool rebaseAbsoluteFileUrlForV024,
  required bool attachAuthForSameOriginAbsolute,
}) {
  final authFingerprint = authHeader == null || authHeader.trim().isEmpty
      ? 0
      : authHeader.trim().hashCode;
  return '${memo.uid}|'
      '${memo.contentFingerprint}|'
      '${memo.updateTime.toUtc().millisecondsSinceEpoch}|'
      '${memo.attachments.length}|'
      '${baseUrl?.toString() ?? ''}|'
      '$authFingerprint|'
      '${rebaseAbsoluteFileUrlForV024 ? 1 : 0}|'
      '${attachAuthForSameOriginAbsolute ? 1 : 0}';
}

class MemosListMemoCardContainer extends ConsumerWidget {
  const MemosListMemoCardContainer({
    super.key,
    required this.memoCardKey,
    required this.memo,
    required this.heroTag,
    required this.prefs,
    required this.outboxStatus,
    required this.tagColors,
    required this.removing,
    required this.searching,
    required this.windowsHeaderSearchExpanded,
    required this.selectedQuickSearchKind,
    required this.searchQuery,
    required this.playingMemoUid,
    required this.audioPlaying,
    required this.audioLoading,
    required this.audioPositionListenable,
    required this.audioDurationListenable,
    required this.onAudioSeek,
    required this.onAudioTap,
    required this.onSyncStatusTap,
    required this.onToggleTask,
    required this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.onFloatingStateChanged,
    required this.onAction,
  });

  final GlobalKey<MemoListCardState> memoCardKey;
  final LocalMemo memo;
  final Object? heroTag;
  final AppPreferences prefs;
  final OutboxMemoStatus outboxStatus;
  final TagColorLookup tagColors;
  final bool removing;
  final bool searching;
  final bool windowsHeaderSearchExpanded;
  final QuickSearchKind? selectedQuickSearchKind;
  final String searchQuery;
  final String? playingMemoUid;
  final bool audioPlaying;
  final bool audioLoading;
  final ValueListenable<Duration> audioPositionListenable;
  final ValueListenable<Duration?> audioDurationListenable;
  final ValueChanged<Duration>? onAudioSeek;
  final VoidCallback? onAudioTap;
  final ValueChanged<MemoSyncStatus>? onSyncStatusTap;
  final ValueChanged<int> onToggleTask;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onFloatingStateChanged;
  final ValueChanged<MemoCardAction> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayTime = memo.effectiveDisplayTime.millisecondsSinceEpoch > 0
        ? memo.effectiveDisplayTime
        : memo.updateTime;
    final isAudioActive = playingMemoUid == memo.uid;
    final isAudioPlaying = isAudioActive && audioPlaying;
    final isAudioLoading = isAudioActive && audioLoading;
    final session = ref.watch(appSessionProvider).valueOrNull;
    final account = session?.currentAccount;
    final baseUrl = account?.baseUrl;
    final sessionController = ref.read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final rebaseAbsoluteFileUrlForV024 = isServerVersion024(serverVersion);
    final attachAuthForSameOriginAbsolute = isServerVersion021(serverVersion);
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? null : 'Bearer $token';
    final mediaCacheKey = _memoMediaEntriesCacheKey(
      memo: memo,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    );
    final cachedMedia = _memoMediaEntriesCache.get(mediaCacheKey);
    final imageEntries =
        cachedMedia?.imageEntries ??
        collectMemoImageEntries(
          content: memo.content,
          attachments: memo.attachments,
          baseUrl: baseUrl,
          authHeader: authHeader,
          rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
          attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
        );
    final videoEntries =
        cachedMedia?.videoEntries ??
        collectMemoVideoEntries(
          attachments: memo.attachments,
          baseUrl: baseUrl,
          authHeader: authHeader,
          rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
          attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
        );
    final mediaEntries =
        cachedMedia?.mediaEntries ??
        buildMemoMediaEntries(images: imageEntries, videos: videoEntries);
    if (cachedMedia == null) {
      _memoMediaEntriesCache.set(
        mediaCacheKey,
        _MemoMediaEntriesCacheEntry(
          imageEntries: imageEntries,
          videoEntries: videoEntries,
          mediaEntries: mediaEntries,
        ),
      );
    }
    final suppressRemovingMediaOnWindows =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        removing &&
        mediaEntries.isNotEmpty;
    if (suppressRemovingMediaOnWindows) {
      ref
          .read(logManagerProvider)
          .info(
            'Memo delete animation suppressing media grid on Windows',
            context: <String, Object?>{
              ...buildMemoContentDiagnostics(memo.content, memoUid: memo.uid),
              'attachmentCount': memo.attachments.length,
              'imageEntryCount': imageEntries.length,
              'videoEntryCount': videoEntries.length,
              'mediaEntryCount': mediaEntries.length,
            },
          );
    }
    final effectiveMediaEntries = suppressRemovingMediaOnWindows
        ? const <MemoMediaEntry>[]
        : mediaEntries;
    final locationProvider = ref.watch(
      locationSettingsProvider.select((value) => value.provider),
    );
    final syncStatus = _resolveMemoSyncStatus(memo, outboxStatus);
    final reminder = ref.watch(memoReminderByUidProvider(memo.uid));
    final reminderSettings = ref.watch(reminderSettingsProvider);
    final nextReminderTime = reminder == null
        ? null
        : nextEffectiveReminderTime(
            now: DateTime.now(),
            times: reminder.times,
            settings: reminderSettings,
          );
    final reminderText = nextReminderTime == null
        ? null
        : _formatReminderTime(context, nextReminderTime);
    final trimmedSearchQuery = searchQuery.trim();
    final inSearchContext =
        searching ||
        windowsHeaderSearchExpanded ||
        trimmedSearchQuery.isNotEmpty ||
        selectedQuickSearchKind != null;

    return MemoListCard(
      key: memoCardKey,
      memo: memo,
      heroTag: heroTag,
      debugRemoving: removing,
      dateText: _memoDateFormatter.format(displayTime),
      reminderText: reminderText,
      tagColors: tagColors,
      initiallyExpanded: inSearchContext,
      highlightQuery: trimmedSearchQuery.isEmpty ? null : trimmedSearchQuery,
      collapseLongContent: prefs.collapseLongContent,
      collapseReferences: prefs.collapseReferences,
      isAudioPlaying: removing ? false : isAudioPlaying,
      isAudioLoading: removing ? false : isAudioLoading,
      audioPositionListenable: removing || !isAudioActive
          ? null
          : audioPositionListenable,
      audioDurationListenable: removing || !isAudioActive
          ? null
          : audioDurationListenable,
      imageEntries: imageEntries,
      mediaEntries: effectiveMediaEntries,
      locationProvider: locationProvider,
      onAudioSeek: removing || !isAudioActive ? null : onAudioSeek,
      onAudioTap: removing ? null : onAudioTap,
      syncStatus: syncStatus,
      onSyncStatusTap: syncStatus == MemoSyncStatus.none
          ? null
          : () => onSyncStatusTap?.call(syncStatus),
      onToggleTask: removing ? (_) {} : onToggleTask,
      onTap: removing ? () {} : onTap,
      onDoubleTap: removing || memo.state == 'ARCHIVED' ? () {} : onDoubleTap,
      onLongPress: removing ? () {} : onLongPress,
      onFloatingStateChanged: onFloatingStateChanged,
      onAction: removing ? (_) {} : onAction,
    );
  }
}

MemoSyncStatus _resolveMemoSyncStatus(LocalMemo memo, OutboxMemoStatus status) {
  final uid = memo.uid.trim();
  if (uid.isEmpty) return MemoSyncStatus.none;
  if (status.failed.contains(uid)) return MemoSyncStatus.failed;
  if (status.pending.contains(uid)) return MemoSyncStatus.pending;
  return switch (memo.syncState) {
    SyncState.error => MemoSyncStatus.failed,
    SyncState.pending => MemoSyncStatus.pending,
    _ => MemoSyncStatus.none,
  };
}

String _formatReminderTime(BuildContext context, DateTime time) {
  final locale = Localizations.localeOf(context).toString();
  final datePart = DateFormat.Md(locale).format(time);
  final timePart = DateFormat.Hm(locale).format(time);
  return '$datePart $timePart';
}
