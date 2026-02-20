import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/desktop_tray_controller.dart';
import 'data/logs/log_manager.dart';
import 'core/desktop_quick_input_channel.dart';
import 'features/memos/desktop_quick_input_window.dart';

void _initializeDesktopDatabaseFactory() {
  if (kIsWeb) return;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      break;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      break;
  }
}

void main(List<String> args) {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      VideoPlayerMediaKit.ensureInitialized(windows: true, linux: false);
      JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
      if (!kIsWeb && args.isNotEmpty && args.first == 'multi_window') {
        final windowId = args.length > 1 ? int.tryParse(args[1]) ?? 0 : 0;
        final rawArgs = args.length > 2 ? args[2] : '';
        final launchArgs = () {
          if (rawArgs.trim().isEmpty) return const <String, dynamic>{};
          try {
            final decoded = jsonDecode(rawArgs);
            if (decoded is Map) {
              return decoded.cast<String, dynamic>();
            }
          } catch (_) {}
          return const <String, dynamic>{};
        }();
        final type = launchArgs[desktopWindowTypeKey];
        // This app currently uses desktop_multi_window only for quick input.
        // Treat unknown/empty payloads as quick input to avoid accidental
        // fallback to the full main app in sub-window engines.
        if (type == null || type == desktopWindowTypeQuickInput) {
          _initializeDesktopDatabaseFactory();
          Cryptography.instance = FlutterCryptography();
          runApp(
            ProviderScope(
              child: DesktopQuickInputWindowApp(windowId: windowId),
            ),
          );
          return;
        }
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        await windowManager.ensureInitialized();
        const options = WindowOptions(
          size: Size(1360, 860),
          center: true,
          backgroundColor: Color(0x00000000),
        );
        windowManager.waitUntilReadyToShow(options, () async {
          await windowManager.setAsFrameless();
          await windowManager.setHasShadow(false);
          await windowManager.show();
          await windowManager.focus();
        });
      }
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        await DesktopTrayController.instance.ensureInitialized();
      }
      _initializeDesktopDatabaseFactory();
      Cryptography.instance = FlutterCryptography();
      FlutterError.onError = (details) {
        LogManager.instance.error(
          'Flutter error',
          error: details.exception,
          stackTrace: details.stack,
        );
        FlutterError.presentError(details);
      };
      ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
        LogManager.instance.error(
          'Platform dispatcher error',
          error: error,
          stackTrace: stackTrace,
        );
        return false;
      };
      runApp(const ProviderScope(child: App()));
    },
    (error, stackTrace) {
      LogManager.instance.error(
        'Uncaught zone error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}
