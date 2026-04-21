import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'application/desktop/desktop_tray_controller.dart';
import 'application/desktop/single_instance_coordinator.dart';
import 'core/app_channel.dart';
import 'core/desktop_runtime_role.dart';
import 'core/debug_ephemeral_storage.dart';
import 'core/startup_timing.dart';
import 'data/logs/log_manager.dart';
import 'core/desktop_quick_input_channel.dart';
import 'features/desktop/quick_input/desktop_quick_input_window.dart';
import 'features/settings/desktop_settings_window_app.dart';

const String _kMediaKitNativeReferenceHolderPrefix =
    'com.alexmercerind.media_kit.NativeReferenceHolder.';

void _configureAndroidPhotoPicker() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  if (!isPlayAppChannel) {
    return;
  }
  final imagePickerImplementation = ImagePickerPlatform.instance;
  if (imagePickerImplementation is ImagePickerAndroid) {
    imagePickerImplementation.useAndroidPhotoPicker = true;
  }
}

void _initializeDesktopDatabaseFactory() {
  if (kIsWeb) return;
  final isDesktopPlatform =
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
  if (isDesktopPlatform) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

void _schedulePostFirstFrameInit() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_postFirstFrameInit());
  });
}

Future<void> _cleanupStaleMediaKitDebugFiles() async {
  if (!kDebugMode || kIsWeb || !Platform.isWindows) {
    return;
  }

  try {
    final files = await Directory.systemTemp
        .list()
        .where(
          (entity) =>
              entity is File &&
              entity.path
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith(_kMediaKitNativeReferenceHolderPrefix),
        )
        .cast<File>()
        .toList();

    var deletedCount = 0;
    for (final file in files) {
      try {
        await file.delete();
        deletedCount += 1;
      } catch (_) {}
    }

    if (deletedCount > 0) {
      LogManager.instance.info(
        'MediaKit debug temp cleanup',
        context: {'deletedFiles': deletedCount},
      );
    }
  } catch (error, stackTrace) {
    LogManager.instance.warn(
      'MediaKit debug temp cleanup failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

Future<void> _postFirstFrameInit() async {
  try {
    await LogManager.instance.init();
  } catch (_) {}
  await _cleanupStaleMediaKitDebugFiles();
  try {
    VideoPlayerMediaKit.ensureInitialized(windows: true, linux: false);
  } catch (_) {}
  try {
    JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
  } catch (_) {}
  try {
    Cryptography.instance = FlutterCryptography();
  } catch (_) {}
}

void main(List<String> args) {
  StartupTiming.init();
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _configureAndroidPhotoPicker();
      StartupTiming.bindFirstFrameTiming();
      final isMultiWindow =
          !kIsWeb && args.isNotEmpty && args.first == 'multi_window';
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.windows &&
          !isMultiWindow) {
        final instance = await SingleInstanceCoordinator.ensureSingleInstance(
          enable: true,
        );
        if (!instance.isPrimary) {
          exit(0);
        }
      }
      await prepareEphemeralDebugStorage(clearExisting: !isMultiWindow);
      StartupTiming.markStep('debug_storage_ready');

      if (isMultiWindow) {
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
        // Treat unknown/empty payloads as quick input to avoid accidental
        // fallback to the full main app in sub-window engines.
        if (type == null || type == desktopWindowTypeQuickInput) {
          _initializeDesktopDatabaseFactory();
          StartupTiming.markRunApp(target: 'desktop_quick_input');
          runApp(
            ProviderScope(
              overrides: [
                desktopRuntimeRoleProvider.overrideWith(
                  (ref) => DesktopRuntimeRole.desktopQuickInput,
                ),
                desktopWindowIdProvider.overrideWith((ref) => windowId),
              ],
              child: DesktopQuickInputWindowApp(windowId: windowId),
            ),
          );
          _schedulePostFirstFrameInit();
          return;
        }
        if (type == desktopWindowTypeSettings) {
          _initializeDesktopDatabaseFactory();
          StartupTiming.markRunApp(target: 'desktop_settings');
          runApp(
            ProviderScope(
              overrides: [
                desktopRuntimeRoleProvider.overrideWith(
                  (ref) => DesktopRuntimeRole.desktopSettings,
                ),
                desktopWindowIdProvider.overrideWith((ref) => windowId),
              ],
              child: DesktopSettingsWindowApp(windowId: windowId),
            ),
          );
          _schedulePostFirstFrameInit();
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
      StartupTiming.markRunApp(target: 'main_app');
      runApp(
        ProviderScope(
          overrides: [
            desktopRuntimeRoleProvider.overrideWith(
              (ref) => DesktopRuntimeRole.mainApp,
            ),
            desktopWindowIdProvider.overrideWith((ref) => 0),
          ],
          child: const App(),
        ),
      );
      _schedulePostFirstFrameInit();
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
