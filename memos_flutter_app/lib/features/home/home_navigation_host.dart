import 'package:flutter/material.dart';

import '../../data/models/home_navigation_preferences.dart';
import '../home/app_drawer.dart';

enum HomeScreenPresentation { standalone, embeddedBottomNav }

abstract interface class HomeEmbeddedNavigationHost {
  void handleDrawerDestination(
    BuildContext context,
    AppDrawerDestination destination,
  );

  void handleDrawerTag(BuildContext context, String tag);

  void handleOpenNotifications(BuildContext context);

  void handleBackToPrimaryDestination(BuildContext context);

  void updateGlobalSwipeExclusionRects(
    HomeRootDestination destination,
    List<Rect> rects,
  );

  void clearGlobalSwipeExclusionRects(HomeRootDestination destination);
}
