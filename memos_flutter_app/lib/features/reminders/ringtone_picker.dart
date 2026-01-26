import 'package:flutter/services.dart';

class RingtoneInfo {
  const RingtoneInfo({
    required this.uri,
    required this.title,
    required this.isSilent,
    required this.isDefault,
  });

  final String? uri;
  final String? title;
  final bool isSilent;
  final bool isDefault;
}

class RingtonePicker {
  static const MethodChannel _channel = MethodChannel('memoflow/ringtone');

  static Future<RingtoneInfo?> pick({String? currentUri}) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'pickRingtone',
        {'currentUri': currentUri},
      );
      if (result == null) return null;
      final map = result.cast<String, dynamic>();
      final uri = map['uri'] as String?;
      final title = map['title'] as String?;
      final isSilent = map['isSilent'] == true;
      final isDefault = map['isDefault'] == true;
      return RingtoneInfo(
        uri: uri,
        title: title,
        isSilent: isSilent,
        isDefault: isDefault,
      );
    } on PlatformException {
      return null;
    }
  }
}
