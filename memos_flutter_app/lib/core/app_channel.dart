import 'package:flutter/foundation.dart';

enum AppChannel { play, full }

const String _kAppChannelDefine = String.fromEnvironment(
  'APP_CHANNEL',
  defaultValue: 'play',
);

@visibleForTesting
AppChannel? debugAppChannelOverride;

AppChannel get currentAppChannel =>
    debugAppChannelOverride ?? _parseAppChannel(_kAppChannelDefine);

bool get isPlayAppChannel => currentAppChannel == AppChannel.play;

bool get isFullAppChannel => currentAppChannel == AppChannel.full;

AppChannel _parseAppChannel(String rawValue) {
  return switch (rawValue.trim().toLowerCase()) {
    'full' => AppChannel.full,
    _ => AppChannel.play,
  };
}
