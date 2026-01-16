import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AutoLockTime {
  immediately('立即'),
  after1Min('1 分钟'),
  after5Min('5 分钟'),
  after15Min('15 分钟');

  const AutoLockTime(this.label);
  final String label;
}

class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.autoLockTime,
    required this.hasPassword,
  });

  final bool enabled;
  final AutoLockTime autoLockTime;
  final bool hasPassword;

  AppLockState copyWith({
    bool? enabled,
    AutoLockTime? autoLockTime,
    bool? hasPassword,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      autoLockTime: autoLockTime ?? this.autoLockTime,
      hasPassword: hasPassword ?? this.hasPassword,
    );
  }
}

final appLockProvider = StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController();
});

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController()
      : super(
          const AppLockState(
            enabled: false,
            autoLockTime: AutoLockTime.immediately,
            hasPassword: false,
          ),
        );

  void setEnabled(bool v) => state = state.copyWith(enabled: v);
  void setAutoLockTime(AutoLockTime v) => state = state.copyWith(autoLockTime: v);
  void setHasPassword(bool v) => state = state.copyWith(hasPassword: v);
}

