import 'dart:io';

import 'package:flutter/services.dart';

enum SystemSettingsTarget {
  app,
  notifications,
  notificationChannel,
  exactAlarm,
  batteryOptimization,
}

class SystemSettingsLauncher {
  static const MethodChannel _channel = MethodChannel('memoflow/system_settings');

  static Future<bool> open(SystemSettingsTarget target, {String? channelId}) async {
    if (!Platform.isAndroid) return false;
    final method = switch (target) {
      SystemSettingsTarget.app => 'openAppSettings',
      SystemSettingsTarget.notifications => 'openNotificationSettings',
      SystemSettingsTarget.notificationChannel => 'openNotificationChannelSettings',
      SystemSettingsTarget.exactAlarm => 'openExactAlarmSettings',
      SystemSettingsTarget.batteryOptimization => 'openBatteryOptimizationSettings',
    };
    try {
      final result = await _channel.invokeMethod<bool>(
        method,
        channelId == null ? null : {'channelId': channelId},
      );
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> requestExactAlarmsPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('requestExactAlarmsPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
