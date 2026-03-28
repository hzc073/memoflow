import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class MemoFlowDeviceNameResolver {
  const MemoFlowDeviceNameResolver();

  Future<String> resolve() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final brand = info.brand.trim();
        final model = info.model.trim();
        final value = [brand, model].where((part) => part.isNotEmpty).join(' ');
        if (value.isNotEmpty) return value;
      }
      if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        final value = info.computerName.trim();
        if (value.isNotEmpty) return value;
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final value = info.name.trim();
        if (value.isNotEmpty) return value;
      }
    } catch (_) {}
    final fallback = Platform.localHostname.trim();
    if (fallback.isNotEmpty) return fallback;
    return 'MemoFlow Device';
  }
}
