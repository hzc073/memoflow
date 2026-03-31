import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/voice/voice_record_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:record/record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'quick mode uses oscilloscope painter and faster amplitude interval',
    (tester) async {
      final recorder = _FakeVoiceRecordRecorder();
      addTearDown(recorder.dispose);
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
        mode: VoiceRecordMode.quickFabCompose,
        documentsDirectoryResolver: () async => tempDir,
      );

      expect(recorder.lastAmplitudeInterval, const Duration(milliseconds: 50));
      expect(
        find.byKey(const ValueKey('voice_record_quick_waveform')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('voice_record_standard_waveform')),
        findsNothing,
      );

      recorder.emit(Amplitude(current: -9.0, max: -9.0));
      await tester.pump(const Duration(milliseconds: 16));

      final waveform = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('voice_record_quick_waveform')),
      );
      expect(
        waveform.painter.runtimeType.toString(),
        contains('QuickOscilloscopePainter'),
      );
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
    expect(
      find.byKey(const ValueKey('voice_record_standard_waveform')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('voice_record_quick_waveform')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick mode keeps waveform visible while silent', (tester) async {
    final recorder = _FakeVoiceRecordRecorder();
    addTearDown(recorder.dispose);
    final tempDir = Directory.systemTemp.createTempSync(
      'voice_record_screen_silence_test',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    await _pumpVoiceRecordScreen(
      tester,
      recorder: recorder,
      mode: VoiceRecordMode.quickFabCompose,
      documentsDirectoryResolver: () async => tempDir,
    );

    recorder.emit(Amplitude(current: -120.0, max: -120.0));
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      find.byKey(const ValueKey('voice_record_quick_waveform')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpVoiceRecordScreen(
  WidgetTester tester, {
  required _FakeVoiceRecordRecorder recorder,
  required VoiceRecordMode mode,
  required Future<Directory> Function() documentsDirectoryResolver,
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
              presentation: VoiceRecordPresentation.overlay,
              autoStart: true,
              mode: mode,
              recorder: recorder,
              documentsDirectoryResolver: documentsDirectoryResolver,
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

  void emit(Amplitude amplitude) {
    _amplitudeController.add(amplitude);
  }

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
  Future<void> start({required String path}) async {
    startedPath = path;
  }

  @override
  Future<String?> stop() async => startedPath;
}
