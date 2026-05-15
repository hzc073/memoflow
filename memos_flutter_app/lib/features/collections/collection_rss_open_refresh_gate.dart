import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/memo_collection.dart';
import '../../state/collections/collection_rss_providers.dart';

class CollectionRssOpenRefreshGate extends ConsumerStatefulWidget {
  const CollectionRssOpenRefreshGate({
    super.key,
    required this.collectionId,
    required this.preferences,
    this.delay = const Duration(milliseconds: 500),
    required this.child,
  });

  final String collectionId;
  final CollectionRssRefreshPreferences preferences;
  final Duration delay;
  final Widget child;

  @override
  ConsumerState<CollectionRssOpenRefreshGate> createState() =>
      _CollectionRssOpenRefreshGateState();
}

class _CollectionRssOpenRefreshGateState
    extends ConsumerState<CollectionRssOpenRefreshGate> {
  Timer? _timer;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _scheduleRefresh();
  }

  @override
  void didUpdateWidget(covariant CollectionRssOpenRefreshGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectionId != widget.collectionId) {
      _timer?.cancel();
      _triggered = false;
      _scheduleRefresh();
    } else if (oldWidget.preferences != widget.preferences && !_triggered) {
      _timer?.cancel();
      _scheduleRefresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleRefresh() {
    if (_triggered || !widget.preferences.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _triggered || !widget.preferences.enabled) return;
      _timer = Timer(widget.delay, _triggerRefresh);
    });
  }

  void _triggerRefresh() {
    if (!mounted || _triggered || !widget.preferences.enabled) return;
    _triggered = true;
    try {
      unawaited(
        ref
            .read(rssRefreshCoordinatorProvider)
            .refreshCollectionOnOpen(
              collectionId: widget.collectionId,
              preferences: widget.preferences,
            ),
      );
    } catch (_) {
      // Collection-open refresh is best-effort and must not block reading.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
