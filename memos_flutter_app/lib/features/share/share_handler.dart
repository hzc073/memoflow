import 'dart:async';

import 'package:flutter/services.dart';

enum SharePayloadType { text, images }

class SharePayload {
  const SharePayload({required this.type, this.text, this.paths = const []});

  final SharePayloadType type;
  final String? text;
  final List<String> paths;

  static SharePayload? fromArgs(Object? args) {
    if (args is! Map) return null;
    final rawType = args['type'];
    final type = _parseType(rawType);
    if (type == null) return null;
    final text = args['text'] as String?;
    final rawPaths = args['paths'];
    final paths = <String>[];
    if (rawPaths is List) {
      for (final item in rawPaths) {
        if (item is String && item.trim().isNotEmpty) {
          paths.add(item);
        }
      }
    }
    return SharePayload(type: type, text: text, paths: paths);
  }

  static SharePayloadType? _parseType(Object? raw) {
    if (raw is! String) return null;
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'images' || normalized == 'image') {
      return SharePayloadType.images;
    }
    if (normalized == 'text' || normalized == 'url') {
      return SharePayloadType.text;
    }
    return null;
  }
}

class ShareHandlerService {
  static const MethodChannel _channel = MethodChannel('memoflow/share');

  static void setShareHandler(
    FutureOr<void> Function(SharePayload payload) handler,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openShare') return;
      final payload = SharePayload.fromArgs(call.arguments);
      if (payload == null) return;
      await handler(payload);
    });
  }

  static Future<SharePayload?> consumePendingShare() async {
    try {
      final args = await _channel.invokeMethod<Object>('getPendingShare');
      return SharePayload.fromArgs(args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
