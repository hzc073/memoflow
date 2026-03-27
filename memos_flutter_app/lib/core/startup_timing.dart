import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/logs/log_manager.dart';

class StartupTiming {
  static final Stopwatch _stopwatch = Stopwatch();
  static final Set<String> _logged = <String>{};
  static bool _initialized = false;
  static bool _firstFrameBound = false;
  static int _epochStartMs = 0;

  static void init({String source = 'main'}) {
    if (_initialized) return;
    _initialized = true;
    _epochStartMs = DateTime.now().millisecondsSinceEpoch;
    _stopwatch.start();
    _log('dart_start', extra: {'source': source, 'epochStartMs': _epochStartMs});
  }

  static int get elapsedMs {
    init(source: 'elapsed_read');
    return _stopwatch.elapsedMilliseconds;
  }

  static int get epochStartMs {
    init(source: 'epoch_read');
    return _epochStartMs;
  }

  static void bindFirstFrameTiming() {
    if (_firstFrameBound) return;
    _firstFrameBound = true;
    init(source: 'first_frame_binding');
    WidgetsBinding.instance.addTimingsCallback((timings) {
      if (timings.isEmpty) return;
      _logOnce(
        'first_frame_rasterized',
        extra: () {
          final timing = timings.first;
          return {
            'frameNumber': timing.frameNumber,
            'buildMs': timing.buildDuration.inMicroseconds / 1000,
            'rasterMs': timing.rasterDuration.inMicroseconds / 1000,
            'vsyncOverheadMs': timing.vsyncOverhead.inMicroseconds / 1000,
          };
        },
      );
      _logOnce(
        'flutter_first_frame_ready',
        extra: () {
          final timing = timings.first;
          return {
            'frameNumber': timing.frameNumber,
            'buildMs': timing.buildDuration.inMicroseconds / 1000,
            'rasterMs': timing.rasterDuration.inMicroseconds / 1000,
            'vsyncOverheadMs': timing.vsyncOverhead.inMicroseconds / 1000,
          };
        },
      );
    });
  }

  static void markRunApp({required String target}) {
    init(source: 'run_app');
    _log('run_app', extra: {'target': target});
  }

  static void markMainHomeBuild() {
    init(source: 'main_home_build');
    _logOnce('main_home_build');
  }

  static void markPrefsLoaded() {
    init(source: 'prefs_loaded');
    _logOnce('prefs_loaded');
  }

  static void markSessionReady({
    required String state,
    required bool hasSession,
  }) {
    init(source: 'session_ready');
    _logOnce(
      'session_ready',
      extra: () => {'state': state, 'hasSession': hasSession},
    );
  }

  static void markStep(String step) {
    init(source: 'step');
    _log('step', extra: {'step': step});
  }

  static void markEvent(
    String event, {
    Map<String, Object?>? extra,
    bool once = true,
  }) {
    init(source: 'event');
    if (once) {
      _logOnce(event, extra: () => extra ?? const <String, Object?>{});
      return;
    }
    _log(event, extra: extra);
  }

  static void _logOnce(
    String event, {
    Map<String, Object?> Function()? extra,
  }) {
    if (_logged.contains(event)) return;
    _logged.add(event);
    _log(event, extra: extra?.call());
  }

  static void _log(String event, {Map<String, Object?>? extra}) {
    if (!(kDebugMode || kProfileMode)) return;
    final context = <String, Object?>{
      'elapsedMs': _stopwatch.elapsedMilliseconds,
      'epochMs': DateTime.now().millisecondsSinceEpoch,
    };
    if (extra != null) {
      context.addAll(extra);
    }
    LogManager.instance.info('StartupTiming: $event', context: context);
  }
}
