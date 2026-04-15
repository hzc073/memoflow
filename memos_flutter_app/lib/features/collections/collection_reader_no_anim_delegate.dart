import 'package:flutter/material.dart';

import 'collection_reader_animation_delegate.dart';

class NoAnimDelegate extends CollectionReaderAnimationDelegate {
  const NoAnimDelegate();

  @override
  Duration get duration => Duration.zero;

  @override
  Widget paintTransition({
    required Animation<double> animation,
    required Widget child,
    required ReaderPageTurnDirection direction,
  }) {
    return child;
  }
}
