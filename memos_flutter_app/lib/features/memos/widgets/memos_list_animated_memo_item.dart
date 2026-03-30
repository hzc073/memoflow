import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/platform_layout.dart';
import '../../../core/top_toast.dart';
import '../../../data/models/app_preferences.dart';
import '../../../data/models/local_memo.dart';
import '../../../state/memos/memos_list_providers.dart';
import '../../../state/memos/memos_providers.dart';
import '../../../state/tags/tag_color_lookup.dart';
import '../../../i18n/strings.g.dart';
import 'memos_list_memo_card.dart';
import 'memos_list_memo_card_container.dart';

class MemosListAnimatedMemoItem extends StatelessWidget {
  const MemosListAnimatedMemoItem({
    super.key,
    required this.memoCardKey,
    required this.memo,
    required this.animation,
    required this.prefs,
    required this.outboxStatus,
    required this.removing,
    required this.tagColors,
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
    required this.onDoubleTapEdit,
    required this.onLongPressCopy,
    required this.onFloatingStateChanged,
    required this.onAction,
  });

  final GlobalKey<MemoListCardState> memoCardKey;
  final LocalMemo memo;
  final Animation<double> animation;
  final AppPreferences prefs;
  final OutboxMemoStatus outboxStatus;
  final bool removing;
  final TagColorLookup tagColors;
  final bool searching;
  final bool windowsHeaderSearchExpanded;
  final QuickSearchKind? selectedQuickSearchKind;
  final String searchQuery;
  final String? playingMemoUid;
  final bool audioPlaying;
  final bool audioLoading;
  final ValueListenable<Duration> audioPositionListenable;
  final ValueListenable<Duration?> audioDurationListenable;
  final ValueChanged<Duration> onAudioSeek;
  final VoidCallback onAudioTap;
  final ValueChanged<MemoSyncStatus> onSyncStatusTap;
  final ValueChanged<int> onToggleTask;
  final VoidCallback onTap;
  final VoidCallback onDoubleTapEdit;
  final VoidCallback onLongPressCopy;
  final VoidCallback onFloatingStateChanged;
  final ValueChanged<MemoCardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    Widget memoCard = MemosListMemoCardContainer(
      memoCardKey: memoCardKey,
      memo: memo,
      prefs: prefs,
      outboxStatus: outboxStatus,
      tagColors: tagColors,
      removing: removing,
      searching: searching,
      windowsHeaderSearchExpanded: windowsHeaderSearchExpanded,
      selectedQuickSearchKind: selectedQuickSearchKind,
      searchQuery: searchQuery,
      playingMemoUid: playingMemoUid,
      audioPlaying: audioPlaying,
      audioLoading: audioLoading,
      audioPositionListenable: audioPositionListenable,
      audioDurationListenable: audioDurationListenable,
      onAudioSeek: onAudioSeek,
      onAudioTap: onAudioTap,
      onSyncStatusTap: onSyncStatusTap,
      onToggleTask: onToggleTask,
      onTap: onTap,
      onDoubleTap: () {
        if (prefs.hapticsEnabled) {
          HapticFeedback.selectionClick();
        }
        onDoubleTapEdit();
      },
      onLongPress: () async {
        if (prefs.hapticsEnabled) {
          HapticFeedback.selectionClick();
        }
        await Clipboard.setData(ClipboardData(text: memo.content));
        if (!context.mounted) return;
        showTopToast(
          context,
          context.t.strings.legacy.msg_memo_copied,
          duration: const Duration(milliseconds: 1200),
        );
        onLongPressCopy();
      },
      onFloatingStateChanged: onFloatingStateChanged,
      onAction: onAction,
    );
    if (Platform.isWindows) {
      memoCard = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kMemoFlowDesktopMemoCardMaxWidth,
          ),
          child: memoCard,
        ),
      );
    }
    return SizeTransition(
      sizeFactor: curved,
      axis: Axis.vertical,
      axisAlignment: 0.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: memoCard,
      ),
    );
  }
}
