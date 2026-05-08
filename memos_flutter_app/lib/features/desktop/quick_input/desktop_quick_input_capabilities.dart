import '../../../core/desktop_runtime_role.dart';

bool desktopQuickInputCanUseLocationPicker({
  required DesktopRuntimeRole runtimeRole,
  required bool isWindows,
}) {
  return !(isWindows && runtimeRole == DesktopRuntimeRole.desktopQuickInput);
}
