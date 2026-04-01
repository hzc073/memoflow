import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/voice/android_quick_spectrum_recorder.dart';
import 'package:memos_flutter_app/features/voice/quick_spectrum_frame.dart';
import 'package:memos_flutter_app/features/voice/voice_record_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:record/record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('quick mode uses Android spectrum painter and m4a output', (
    tester,
  ) async {
    final recorder = _FakeVoiceRecordRecorder();
    final quickRecorder = _FakeAndroidQuickSpectrumRecorder();
    addTearDown(recorder.dispose);
    addTearDown(quickRecorder.dispose);
    final tempDir = Directory.systemTemp.createTempSync(
      'voice_record_screen_quick_test',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    await _pumpVoiceRecordScreen(
      tester,
      recorder: recorder,
      quickRecorder: quickRecorder,
      mode: VoiceRecordMode.quickFabCompose,
      documentsDirectoryResolver: () async => tempDir,
    );

    expect(recorder.lastAmplitudeInterval, isNull);
    expect(quickRecorder.startedPath, endsWith('.m4a'));
    expect(
      find.byKey(const ValueKey('voice_record_quick_spectrum')),
      findsOneWidget,
    );

    quickRecorder.emit(
      QuickSpectrumFrame(
        bars: List<double>.filled(QuickSpectrumFrame.barCount, 0.7),
        rmsLevel: 0.4,
        peakLevel: 0.8,
        hasVoice: true,
        sequence: 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));

    final spectrum = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('voice_record_quick_spectrum')),
    );
    expect(
      spectrum.painter.runtimeType.toString(),
      contains('AudioSpectrumPainter'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'page quick mode uses quick spectrum and hides standard draft action',
    (tester) async {
      final recorder = _FakeVoiceRecordRecorder();
      final quickRecorder = _FakeAndroidQuickSpectrumRecorder();
      addTearDown(recorder.dispose);
      addTearDown(quickRecorder.dispose);
      final tempDir = Directory.systemTemp.createTempSync(
        'voice_record_screen_page_quick_test',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      await _pumpVoiceRecordScreen(
        tester,
        recorder: recorder,
        quickRecorder: quickRecorder,
        mode: VoiceRecordMode.quickFabCompose,
        presentation: VoiceRecordPresentation.page,
        documentsDirectoryResolver: () async => tempDir,
      );

      expect(recorder.lastAmplitudeInterval, isNull);
      expect(quickRecorder.startedPath, endsWith('.m4a'));
      expect(
        find.byKey(const ValueKey('voice_record_quick_spectrum')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('voice_record_standard_waveform')),
        findsNothing,
      );
      expect(find.text('Slide right to lock'), findsNothing);
      expect(find.text('Slide left to discard'), findsNothing);
      expect(find.text('Release to finish'), findsNothing);
      expect(find.byIcon(Icons.notes_rounded), findsNothing);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      final recPosition = tester.getTopLeft(find.text('REC'));
      final headerPosition = tester.getTopLeft(
        find.byKey(const ValueKey('voice_record_header_label')),
      );
      expect(headerPosition.dx - recPosition.dx, lessThan(120));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('standard mode keeps legacy waveform renderer', (tester) async {
    final recorder = _FakeVoiceRecordRecorder();
    addTearDown(recorder.dispose);
    final tempDir = Directory.systemTemp.createTempSync(
      'voice_record_screen_standard_test',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    await _pumpVoiceRecordScreen(
      tester,
      recorder: recorder,
      mode: VoiceRecordMode.standard,
      documentsDirectoryResolver: () async => tempDir,
    );

    expect(recorder.lastAmplitudeInterval, const Duration(milliseconds: 120));
    expect(recorder.startedPath, endsWith('.m4a'));
    expect(
      find.byKey(const ValueKey('voice_record_standard_waveform')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('voice_record_quick_spectrum')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('page quick mode completes immediately on first stop', (
    tester,
  ) async {
    final recorder = _FakeVoiceRecordRecorder();
    addTearDown(recorder.dispose);
    final tempDir = Directory.systemTemp.createTempSync(
      'voice_record_screen_page_quick_complete_test',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    VoiceRecordResult? completedResult;
    await _pumpVoiceRecordScreen(
      tester,
      recorder: recorder,
      mode: VoiceRecordMode.quickFabCompose,
      presentation: VoiceRecordPresentation.page,
      documentsDirectoryResolver: () async => tempDir,
      onComplete: (result) => completedResult = result,
    );

    await tester.tap(find.byKey(const ValueKey('voice_record_primary_button')));
    await tester.pump();

    expect(completedResult, isNotNull);
    expect(completedResult!.filePath, recorder.startedPath);
    expect(completedResult!.fileName, isNotEmpty);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page quick mode pause button toggles paused state', (
    tester,
  ) async {
    final recorder = _FakeVoiceRecordRecorder();
    final quickRecorder = _FakeAndroidQuickSpectrumRecorder();
    addTearDown(recorder.dispose);
    addTearDown(quickRecorder.dispose);
    final tempDir = Directory.systemTemp.createTempSync(
      'voice_record_screen_page_quick_pause_test',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    await _pumpVoiceRecordScreen(
      tester,
      recorder: recorder,
      quickRecorder: quickRecorder,
      mode: VoiceRecordMode.quickFabCompose,
      presentation: VoiceRecordPresentation.page,
      documentsDirectoryResolver: () async => tempDir,
    );

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();

    expect(quickRecorder.pauseCallCount, 1);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    expect(quickRecorder.resumeCallCount, 1);
    expect(find.text('Recording'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpVoiceRecordScreen(
  WidgetTester tester, {
  required _FakeVoiceRecordRecorder recorder,
  _FakeAndroidQuickSpectrumRecorder? quickRecorder,
  required VoiceRecordMode mode,
  VoiceRecordPresentation presentation = VoiceRecordPresentation.overlay,
  required Future<Directory> Function() documentsDirectoryResolver,
  VoiceRecordCompletionHandler? onComplete,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: VoiceRecordScreen(
              presentation: presentation,
              autoStart: true,
              mode: mode,
              recorder: recorder,
              quickSpectrumRecorder: quickRecorder,
              documentsDirectoryResolver: documentsDirectoryResolver,
              onComplete: onComplete,
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

class _FakeVoiceRecordRecorder implements VoiceRecordRecorder {
  final StreamController<Amplitude> _amplitudeController =
      StreamController<Amplitude>.broadcast();

  Duration? lastAmplitudeInterval;
  String? startedPath;
  var pauseCallCount = 0;
  var resumeCallCount = 0;

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {
    if (!_amplitudeController.isClosed) {
      _amplitudeController.close();
    }
  }

  @override
  Future<bool> hasInputDevice() async => true;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) {
    lastAmplitudeInterval = interval;
    return _amplitudeController.stream;
  }

  @override
  Future<void> pause() async {
    pauseCallCount += 1;
  }

  @override
  Future<void> resume() async {
    resumeCallCount += 1;
  }

  @override
  Future<void> start({required String path}) async {
    startedPath = path;
    final file = File(path);
    file.parent.createSync(recursive: true);
    if (!file.existsSync()) {
      file.writeAsBytesSync(const <int>[0]);
    }
  }

  @override
  Future<String?> stop() async => startedPath;
}

class _FakeAndroidQuickSpectrumRecorder extends AndroidQuickSpectrumRecorder {
  _FakeAndroidQuickSpectrumRecorder();

  final StreamController<QuickSpectrumFrame> _framesController =
      StreamController<QuickSpectrumFrame>.broadcast();

  String? startedPath;
  var pauseCallCount = 0;
  var resumeCallCount = 0;

  void emit(QuickSpectrumFrame frame) {
    _framesController.add(frame);
  }

  @override
  Stream<QuickSpectrumFrame> get frames => _framesController.stream;

  @override
  Future<void> start({required String path}) async {
    startedPath = path;
    final file = File(path);
    file.parent.createSync(recursive: true);
    if (!file.existsSync()) {
      file.writeAsBytesSync(const <int>[0]);
    }
  }

  @override
  Future<void> pause() async {
    pauseCallCount += 1;
  }

  @override
  Future<void> resume() async {
    resumeCallCount += 1;
  }

  @override
  Future<String?> stop() async => startedPath;

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {
    if (!_framesController.isClosed) {
      _framesController.close();
    }
  }
}
