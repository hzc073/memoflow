import 'package:flutter/material.dart';

import 'collection_reader_animation_delegate.dart';

class SlideDelegate extends CollectionReaderAnimationDelegate {
  const SlideDelegate();

  @override
  Duration get duration => const Duration(milliseconds: 220);

  @override
  Widget paintTransition({
    required Animation<double> animation,
    required Widget child,
    required ReaderPageTurnDirection direction,
  }) {
    final begin = switch (direction) {
      ReaderPageTurnDirection.previous => const Offset(-0.16, 0),
      ReaderPageTurnDirection.next => const Offset(0.16, 0),
      ReaderPageTurnDirection.none => Offset.zero,
    };
    final offset = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: offset, child: child),
    );
  }
}
