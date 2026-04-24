import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_motion.dart';
import '../../../core/memo_content_diagnostics.dart';
import '../../../core/platform_layout.dart';
import '../../../core/top_toast.dart';
import '../../../data/models/app_preferences.dart';
import '../../../data/models/local_memo.dart';
import '../../../data/logs/log_manager.dart';
import '../../../state/memos/memos_list_providers.dart';
import '../../../state/memos/memos_providers.dart';
import '../../../state/tags/tag_color_lookup.dart';
import '../../../i18n/strings.g.dart';
import 'memos_list_memo_card.dart';
import 'memos_list_memo_card_container.dart';

final Set<String> _memoDeleteAnimatedItemLogKeys = <String>{};

void _logMemoDeleteAnimatedItemOnce(
  String message,
  LocalMemo memo, {
  Map<String, Object?> context = const <String, Object?>{},
}) {
  final key = '$message|${memo.uid}';
  if (!_memoDeleteAnimatedItemLogKeys.add(key)) return;
  LogManager.instance.info(
    message,
    context: <String, Object?>{
      ...buildMemoContentDiagnostics(memo.content, memoUid: memo.uid),
      'attachmentCount': memo.attachments.length,
      ...context,
    },
  );
}

class MemosListAnimatedMemoItem extends StatelessWidget {
  const MemosListAnimatedMemoItem({
    super.key,
    required this.memoCardKey,
    required this.memo,
    required this.heroTag,
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
  final Object? heroTag;
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
    final curved = CurvedAnimation(
      parent: animation,
      curve: removing ? AppMotion.exitCurve : AppMotion.standardCurve,
    );
    if (!kIsWeb && Platform.isWindows && removing) {
      _logMemoDeleteAnimatedItemOnce(
        'Memo delete animated item build',
        memo,
        context: <String, Object?>{
          'animationValue': animation.value.toStringAsFixed(3),
          'animationStatus': animation.status.name,
          'curvedValue': curved.value.toStringAsFixed(3),
          'curvedStatus': curved.status.name,
          'willConstrainDesktopWidth': true,
        },
      );
    }
    Widget memoCard = MemosListMemoCardContainer(
      memoCardKey: memoCardKey,
      memo: memo,
      heroTag: heroTag,
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
    if (removing) {
      if (!kIsWeb && Platform.isWindows) {
        _logMemoDeleteAnimatedItemOnce(
          'Memo delete animated item wrapped with semantics suppression',
          memo,
          context: <String, Object?>{
            'animationValue': animation.value.toStringAsFixed(3),
            'animationStatus': animation.status.name,
            'usingExcludeSemantics': true,
            'usingIgnorePointer': true,
          },
        );
      }
      memoCard = ExcludeSemantics(
        child: IgnorePointer(ignoring: true, child: memoCard),
      );
    }
    return FadeTransition(
      opacity: curved,
      child: SizeTransition(
        sizeFactor: curved,
        axis: Axis.vertical,
        axisAlignment: 0.0,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: memoCard,
        ),
      ),
    );
  }
}
