import '../../data/models/home_navigation_preferences.dart';

const List<HomeRootDestination> kHomeRootDestinationPickerOrder = [
  HomeRootDestination.memos,
  HomeRootDestination.explore,
  HomeRootDestination.dailyReview,
  HomeRootDestination.settings,
  HomeRootDestination.aiSummary,
  HomeRootDestination.resources,
  HomeRootDestination.archived,
  HomeRootDestination.none,
];

const List<HomeRootDestination> _kHomeRootDestinationFallbackOrder = [
  HomeRootDestination.memos,
  HomeRootDestination.dailyReview,
  HomeRootDestination.settings,
  HomeRootDestination.aiSummary,
  HomeRootDestination.resources,
  HomeRootDestination.archived,
  HomeRootDestination.none,
];

class ResolvedHomeNavigationPreferences {
  const ResolvedHomeNavigationPreferences({
    required this.mode,
    required this.leftPrimary,
    required this.leftSecondary,
    required this.rightPrimary,
    required this.rightSecondary,
  });

  final HomeNavigationMode mode;
  final HomeRootDestination leftPrimary;
  final HomeRootDestination leftSecondary;
  final HomeRootDestination rightPrimary;
  final HomeRootDestination rightSecondary;

  List<HomeRootDestination> get slots => [
    leftPrimary,
    leftSecondary,
    rightPrimary,
    rightSecondary,
  ];

  List<HomeRootDestination> get visibleTabs => [
    for (final destination in slots)
      if (destination != HomeRootDestination.none) destination,
  ];

  HomeRootDestination fallbackDestinationFor(HomeRootDestination? current) {
    if (current != null && visibleTabs.contains(current)) {
      return current;
    }
    if (visibleTabs.contains(HomeRootDestination.memos)) {
      return HomeRootDestination.memos;
    }
    return visibleTabs.isEmpty ? HomeRootDestination.memos : visibleTabs.first;
  }

  HomeNavigationPreferences toPreferences() {
    return HomeNavigationPreferences(
      mode: mode,
      leftPrimary: leftPrimary,
      leftSecondary: leftSecondary,
      rightPrimary: rightPrimary,
      rightSecondary: rightSecondary,
    );
  }
}

bool isHomeRootDestinationAvailable(
  HomeRootDestination destination, {
  required bool hasAccount,
}) {
  return switch (destination) {
    HomeRootDestination.none => true,
    HomeRootDestination.explore => hasAccount,
    HomeRootDestination.memos ||
    HomeRootDestination.dailyReview ||
    HomeRootDestination.settings ||
    HomeRootDestination.aiSummary ||
    HomeRootDestination.resources ||
    HomeRootDestination.archived => true,
  };
}

ResolvedHomeNavigationPreferences resolveHomeNavigationPreferences(
  HomeNavigationPreferences preferences, {
  required bool hasAccount,
}) {
  final resolved = <HomeRootDestination>[];
  final seen = <HomeRootDestination>{};

  for (final slot in [
    preferences.leftPrimary,
    preferences.leftSecondary,
    preferences.rightPrimary,
    preferences.rightSecondary,
  ]) {
    if (slot == HomeRootDestination.none) {
      resolved.add(HomeRootDestination.none);
      continue;
    }

    if (isHomeRootDestinationAvailable(slot, hasAccount: hasAccount) &&
        seen.add(slot)) {
      resolved.add(slot);
      continue;
    }

    resolved.add(
      _resolveFallbackDestination(seen: seen, hasAccount: hasAccount),
    );
  }

  if (resolved.every((destination) => destination == HomeRootDestination.none)) {
    resolved[0] = HomeRootDestination.memos;
  }

  return ResolvedHomeNavigationPreferences(
    mode: preferences.mode,
    leftPrimary: resolved[0],
    leftSecondary: resolved[1],
    rightPrimary: resolved[2],
    rightSecondary: resolved[3],
  );
}

HomeNavigationPreferences sanitizeHomeNavigationPreferences(
  HomeNavigationPreferences preferences, {
  required bool hasAccount,
}) {
  return resolveHomeNavigationPreferences(
    preferences,
    hasAccount: hasAccount,
  ).toPreferences();
}

HomeRootDestination _resolveFallbackDestination({
  required Set<HomeRootDestination> seen,
  required bool hasAccount,
}) {
  for (final candidate in _kHomeRootDestinationFallbackOrder) {
    if (candidate == HomeRootDestination.none) {
      return HomeRootDestination.none;
    }
    if (!isHomeRootDestinationAvailable(candidate, hasAccount: hasAccount)) {
      continue;
    }
    if (seen.contains(candidate)) continue;
    seen.add(candidate);
    return candidate;
  }
  return HomeRootDestination.none;
}
