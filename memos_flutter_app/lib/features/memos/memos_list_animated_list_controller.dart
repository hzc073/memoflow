import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_motion.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import 'widgets/memos_list_memo_card.dart';

typedef AnimatedRemovedItemBuilder =
    Widget Function(BuildContext context, Animation<double> animation);

class MemosListAnimatedListController extends ChangeNotifier {
  final Map<String, GlobalKey<MemoListCardState>> _memoCardKeys =
      <String, GlobalKey<MemoListCardState>>{};
  GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();
  List<LocalMemo> _animatedMemos = <LocalMemo>[];
  String _listSignature = '';
  final Set<String> _pendingRemovedUids = <String>{};

  GlobalKey<SliverAnimatedListState> get listKey => _listKey;
  List<LocalMemo> get animatedMemos =>
      List<LocalMemo>.unmodifiable(_animatedMemos);
  String get listSignature => _listSignature;
  Set<String> get pendingRemovedUids =>
      Set<String>.unmodifiable(_pendingRemovedUids);

  GlobalKey<MemoListCardState> keyFor(String memoUid) {
    return _memoCardKeys.putIfAbsent(memoUid, GlobalKey<MemoListCardState>.new);
  }

  MemoListCardState? currentStateFor(String memoUid) {
    return _memoCardKeys[memoUid]?.currentState;
  }

  void syncMemoCardKeys(List<LocalMemo> memos) {
    final keepUids = memos.map((memo) => memo.uid).toSet();
    _memoCardKeys.removeWhere((uid, _) => !keepUids.contains(uid));
  }

  String? resolveFloatingCollapseMemoUid(GlobalKey viewportKey) {
    final viewportRect = globalRectForKey(viewportKey);
    if (viewportRect == null) return null;

    MemoFloatingCollapseCandidate? nextCandidate;
    for (final key in _memoCardKeys.values) {
      final candidate = key.currentState?.resolveFloatingCollapseCandidate(
        viewportRect,
      );
      if (candidate == null) continue;
      if (nextCandidate == null ||
          candidate.visibleHeight > nextCandidate.visibleHeight) {
        nextCandidate = candidate;
      }
    }
    return nextCandidate?.memoUid;
  }

  void removeMemoWithAnimation(
    LocalMemo memo, {
    bool animationsEnabled = true,
    required AnimatedRemovedItemBuilder builder,
  }) {
    final index = _animatedMemos.indexWhere((m) => m.uid == memo.uid);
    if (index < 0) return;
    final removed = _animatedMemos.removeAt(index);
    _pendingRemovedUids.add(removed.uid);
    _listKey.currentState?.removeItem(
      index,
      builder,
      duration: animationsEnabled ? AppMotion.exit : Duration.zero,
    );
    notifyListeners();
  }

  void syncAnimatedMemos(
    List<LocalMemo> memos,
    String signature, {
    bool animationsEnabled = true,
    required void Function(String event, Map<String, Object?> context) logEvent,
    required void Function({
      required int beforeLength,
      required int afterLength,
      required bool signatureChanged,
      required bool listChanged,
      required String fromSignature,
      required String toSignature,
      required List<String> removedSample,
    })
    logVisibleDecrease,
    required ScrollMetrics? metrics,
    required void Function(VoidCallback callback) schedulePostFrame,
  }) {
    if (_pendingRemovedUids.isNotEmpty) {
      final memoIds = memos.map((m) => m.uid).toSet();
      _pendingRemovedUids.removeWhere((uid) => !memoIds.contains(uid));
    }
    final filtered = memos
        .where((m) => !_pendingRemovedUids.contains(m.uid))
        .toList(growable: true);
    final sameSignature = _listSignature == signature;

    if (sameSignature &&
        _animatedMemos.isNotEmpty &&
        filtered.length > _animatedMemos.length &&
        _sameMemoPrefix(_animatedMemos, filtered)) {
      final insertStart = _animatedMemos.length;
      final insertCount = filtered.length - _animatedMemos.length;
      logEvent('animated_list_append_prepare', <String, Object?>{
        'signature': signature,
        'beforeLength': _animatedMemos.length,
        'afterLength': filtered.length,
        'insertStart': insertStart,
        'insertCount': insertCount,
        if (metrics != null) 'pixels': metrics.pixels,
      });
      _animatedMemos = filtered;
      schedulePostFrame(() {
        final state = _listKey.currentState;
        if (state == null) return;
        for (var i = 0; i < insertCount; i++) {
          state.insertItem(
            insertStart + i,
            duration: animationsEnabled ? AppMotion.medium : Duration.zero,
          );
        }
        logEvent('animated_list_append_applied', <String, Object?>{
          'signature': signature,
          'insertCount': insertCount,
          'currentLength': _animatedMemos.length,
          if (metrics != null) 'pixels': metrics.pixels,
        });
      });
      return;
    }

    final signatureChanged = _listSignature != signature;
    final listChanged = !_sameMemoList(_animatedMemos, filtered);
    if (signatureChanged || listChanged) {
      final beforeLength = _animatedMemos.length;
      final afterLength = filtered.length;
      if (afterLength < beforeLength) {
        logVisibleDecrease(
          beforeLength: beforeLength,
          afterLength: afterLength,
          signatureChanged: signatureChanged,
          listChanged: listChanged,
          fromSignature: _listSignature,
          toSignature: signature,
          removedSample: _collectRemovedMemoUids(
            _animatedMemos,
            filtered,
            limit: 8,
          ),
        );
      }
      logEvent('animated_list_rebuild', <String, Object?>{
        'signatureChanged': signatureChanged,
        'listChanged': listChanged,
        'fromSignature': _listSignature,
        'toSignature': signature,
        'beforeLength': beforeLength,
        'afterLength': afterLength,
        'clearedMemoCardKeys': _memoCardKeys.isNotEmpty,
        if (metrics != null) 'pixels': metrics.pixels,
      });
      _listSignature = signature;
      _animatedMemos = filtered;
      _memoCardKeys.clear();
      _listKey = GlobalKey<SliverAnimatedListState>();
      return;
    }

    var changed = false;
    final next = List<LocalMemo>.from(_animatedMemos);
    for (var i = 0; i < filtered.length; i++) {
      if (!_sameMemoData(_animatedMemos[i], filtered[i])) {
        next[i] = filtered[i];
        changed = true;
      }
    }
    if (changed) {
      _animatedMemos = next;
    }
  }

  @override
  void dispose() {
    _memoCardKeys.clear();
    _pendingRemovedUids.clear();
    super.dispose();
  }

  static bool _sameMemoList(List<LocalMemo> a, List<LocalMemo> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].uid != b[i].uid) return false;
    }
    return true;
  }

  static List<String> _collectRemovedMemoUids(
    List<LocalMemo> before,
    List<LocalMemo> after, {
    int limit = 8,
  }) {
    if (before.isEmpty || limit <= 0) return const <String>[];
    final afterUids = after.map((memo) => memo.uid).toSet();
    final removed = <String>[];
    for (final memo in before) {
      if (afterUids.contains(memo.uid)) continue;
      removed.add(memo.uid);
      if (removed.length >= limit) break;
    }
    return removed;
  }

  static bool _sameMemoPrefix(List<LocalMemo> prefix, List<LocalMemo> full) {
    if (prefix.length > full.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i].uid != full[i].uid) return false;
    }
    return true;
  }

  static bool _sameMemoData(LocalMemo a, LocalMemo b) {
    if (identical(a, b)) return true;
    if (a.uid != b.uid) return false;
    if (a.content != b.content) return false;
    if (a.visibility != b.visibility) return false;
    if (a.pinned != b.pinned) return false;
    if (a.state != b.state) return false;
    if (a.createTime != b.createTime) return false;
    if (a.updateTime != b.updateTime) return false;
    if (a.syncState != b.syncState) return false;
    if (a.lastError != b.lastError) return false;
    if (!listEquals(a.tags, b.tags)) return false;
    if (!_sameAttachments(a.attachments, b.attachments)) return false;
    return true;
  }

  static bool _sameAttachments(List<Attachment> a, List<Attachment> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.name != right.name) return false;
      if (left.filename != right.filename) return false;
      if (left.type != right.type) return false;
      if (left.size != right.size) return false;
      if (left.externalLink != right.externalLink) return false;
    }
    return true;
  }
}
