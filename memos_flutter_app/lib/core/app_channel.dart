import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;

enum AppChannel { play, full }

const String _kAppChannelDefine = String.fromEnvironment(
  'APP_CHANNEL',
  defaultValue: '',
);

@visibleForTesting
AppChannel? debugAppChannelOverride;

AppChannel get currentAppChannel =>
    debugAppChannelOverride ??
    resolveAppChannel(flavor: appFlavor, appChannelDefine: _kAppChannelDefine);

bool get isPlayAppChannel => currentAppChannel == AppChannel.play;

bool get isFullAppChannel => currentAppChannel == AppChannel.full;

@visibleForTesting
AppChannel resolveAppChannel({String? flavor, String? appChannelDefine}) {
  final normalizedFlavor = _normalizeChannelString(flavor);
  if (normalizedFlavor != null) {
    return _parseAppChannel(normalizedFlavor);
  }
  final normalizedDefine = _normalizeChannelString(appChannelDefine);
  if (normalizedDefine != null) {
    return _parseAppChannel(normalizedDefine);
  }
  return AppChannel.play;
}

AppChannel _parseAppChannel(String rawValue) {
  return switch (rawValue.trim().toLowerCase()) {
    'full' => AppChannel.full,
    _ => AppChannel.play,
  };
}

String? _normalizeChannelString(String? rawValue) {
  final normalized = rawValue?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
