import '../../data/logs/log_manager.dart';

class LocationPickerLogger {
  const LocationPickerLogger._();

  static void debug(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    LogManager.instance.debug(
      'LocationPicker: $message',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void info(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    LogManager.instance.info(
      'LocationPicker: $message',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void warn(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    LogManager.instance.warn(
      'LocationPicker: $message',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
