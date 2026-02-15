import 'dart:async';
import 'dart:ui' as ui;

import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/logs/log_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  runZonedGuarded(
    () => runApp(const ProviderScope(child: App())),
    (error, stackTrace) {
      LogManager.instance.error(
        'Uncaught zone error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}
