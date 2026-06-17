import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DesktopRuntimeRole {
  mainApp,
  desktopQuickInput,
  desktopSettings,
  desktopShareTask,
  desktopMediaPreview,
}

extension DesktopRuntimeRoleX on DesktopRuntimeRole {
  String get logName => switch (this) {
    DesktopRuntimeRole.mainApp => 'main_app',
    DesktopRuntimeRole.desktopQuickInput => 'desktop_quick_input',
    DesktopRuntimeRole.desktopSettings => 'desktop_settings',
    DesktopRuntimeRole.desktopShareTask => 'desktop_share_task',
    DesktopRuntimeRole.desktopMediaPreview => 'desktop_media_preview',
  };
}

final desktopRuntimeRoleProvider = Provider<DesktopRuntimeRole>((ref) {
  return DesktopRuntimeRole.mainApp;
});

final desktopWindowIdProvider = Provider<int>((ref) {
  return 0;
});
