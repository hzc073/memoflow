import 'dart:async';

import 'package:flutter/services.dart';

import 'quick_spectrum_frame.dart';

class AndroidQuickSpectrumRecorder {
  AndroidQuickSpectrumRecorder({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ??
           const MethodChannel('memoflow/quick_spectrum_recorder'),
       _eventChannel =
           eventChannel ??
           const EventChannel('memoflow/quick_spectrum_recorder/frames');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<QuickSpectrumFrame>? _frames;

  Stream<QuickSpectrumFrame> get frames {
    return _frames ??= _eventChannel
        .receiveBroadcastStream()
        .transform(
          StreamTransformer<Object?, QuickSpectrumFrame>.fromHandlers(
            handleData: (event, sink) {
              final frame = QuickSpectrumFrame.tryParse(event);
              if (frame != null) {
                sink.add(frame);
              }
            },
          ),
        )
        .asBroadcastStream();
  }

  Future<void> start({required String path}) {
    return _methodChannel.invokeMethod<void>('start', <String, Object?>{
      'path': path,
    });
  }

  Future<void> pause() {
    return _methodChannel.invokeMethod<void>('pause');
  }

  Future<void> resume() {
    return _methodChannel.invokeMethod<void>('resume');
  }

  Future<String?> stop() {
    return _methodChannel.invokeMethod<String>('stop');
  }

  Future<void> cancel() {
    return _methodChannel.invokeMethod<void>('cancel');
  }

  void dispose() {}
}
