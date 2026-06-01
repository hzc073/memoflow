import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DesktopQuickRecordHotKeyRegistrationStatus {
  unavailable,
  registered,
  failed,
}

final desktopQuickRecordHotKeyRegistrationStatusProvider =
    StateProvider<DesktopQuickRecordHotKeyRegistrationStatus>(
      (_) => DesktopQuickRecordHotKeyRegistrationStatus.unavailable,
    );

bool desktopQuickRecordHotKeyIsActive(
  DesktopQuickRecordHotKeyRegistrationStatus status,
) {
  return status == DesktopQuickRecordHotKeyRegistrationStatus.registered;
}
