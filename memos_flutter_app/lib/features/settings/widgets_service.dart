import 'dart:async';

import 'package:flutter/services.dart';

enum HomeWidgetType { dailyReview, quickInput, stats }

class HomeWidgetService {
  static const MethodChannel _channel = MethodChannel('memoflow/widgets');

  static Future<bool> requestPinWidget(HomeWidgetType type) async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPinWidget', {
        'type': type.name,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static void setLaunchHandler(
    FutureOr<void> Function(HomeWidgetType type) handler,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openWidget') return;
      final args = call.arguments;
      String? raw;
      if (args is Map) {
        raw = args['action'] as String?;
      } else if (args is String) {
        raw = args;
      }
      final type = _parseType(raw);
      if (type == null) return;
      await handler(type);
    });
  }

  static Future<HomeWidgetType?> consumePendingAction() async {
    try {
      final raw = await _channel.invokeMethod<String>('getPendingWidgetAction');
      return _parseType(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<bool> updateStatsWidget({
    required int total,
    required List<int> days,
    String title = 'Activity Heatmap',
    String totalLabel = 'Total',
    String rangeLabel = 'Last 14 days',
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('updateStatsWidget', {
        'total': total,
        'days': days,
        'title': title,
        'totalLabel': totalLabel,
        'rangeLabel': rangeLabel,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static HomeWidgetType? _parseType(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    for (final type in HomeWidgetType.values) {
      if (type.name == raw) return type;
    }
    return null;
  }
}
