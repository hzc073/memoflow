enum HomeNavigationMode { classic, bottomBar }

enum HomeRootDestination {
  none,
  memos,
  explore,
  dailyReview,
  settings,
  aiSummary,
  resources,
  archived,
}

enum HomeNavigationSlot {
  leftPrimary,
  leftSecondary,
  rightPrimary,
  rightSecondary,
}

class HomeNavigationPreferences {
  const HomeNavigationPreferences({
    required this.mode,
    required this.leftPrimary,
    required this.leftSecondary,
    required this.rightPrimary,
    required this.rightSecondary,
  });

  static const HomeNavigationPreferences defaults = HomeNavigationPreferences(
    mode: HomeNavigationMode.classic,
    leftPrimary: HomeRootDestination.memos,
    leftSecondary: HomeRootDestination.explore,
    rightPrimary: HomeRootDestination.dailyReview,
    rightSecondary: HomeRootDestination.settings,
  );

  final HomeNavigationMode mode;
  final HomeRootDestination leftPrimary;
  final HomeRootDestination leftSecondary;
  final HomeRootDestination rightPrimary;
  final HomeRootDestination rightSecondary;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'leftPrimary': leftPrimary.name,
    'leftSecondary': leftSecondary.name,
    'rightPrimary': rightPrimary.name,
    'rightSecondary': rightSecondary.name,
  };

  factory HomeNavigationPreferences.fromJson(Map<String, dynamic> json) {
    return HomeNavigationPreferences(
      mode: _parseMode(json['mode']),
      leftPrimary: _parseDestination(json['leftPrimary']),
      leftSecondary: _parseDestination(json['leftSecondary']),
      rightPrimary: _parseDestination(json['rightPrimary']),
      rightSecondary: _parseDestination(json['rightSecondary']),
    );
  }

  HomeNavigationPreferences copyWith({
    HomeNavigationMode? mode,
    HomeRootDestination? leftPrimary,
    HomeRootDestination? leftSecondary,
    HomeRootDestination? rightPrimary,
    HomeRootDestination? rightSecondary,
  }) {
    return HomeNavigationPreferences(
      mode: mode ?? this.mode,
      leftPrimary: leftPrimary ?? this.leftPrimary,
      leftSecondary: leftSecondary ?? this.leftSecondary,
      rightPrimary: rightPrimary ?? this.rightPrimary,
      rightSecondary: rightSecondary ?? this.rightSecondary,
    );
  }

  static HomeNavigationMode _parseMode(Object? raw) {
    if (raw is String) {
      for (final value in HomeNavigationMode.values) {
        if (value.name == raw) return value;
      }
    }
    return defaults.mode;
  }

  static HomeRootDestination _parseDestination(Object? raw) {
    if (raw is String) {
      for (final value in HomeRootDestination.values) {
        if (value.name == raw) return value;
      }
    }
    return HomeRootDestination.none;
  }
}
