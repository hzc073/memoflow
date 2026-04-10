import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform_layout.dart';
import '../../data/models/home_navigation_preferences.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import 'home_bottom_nav_shell.dart';
import 'home_screen.dart';

class HomeEntryScreen extends ConsumerWidget {
  const HomeEntryScreen({super.key});

  static WidgetBuilder? debugClassicScreenBuilderOverride;
  static WidgetBuilder? debugBottomNavShellBuilderOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceLoaded = ref.watch(workspacePreferencesLoadedProvider);
    final homeNavigationPreferences = ref.watch(
      currentWorkspacePreferencesProvider.select(
        (prefs) => prefs.homeNavigationPreferences,
      ),
    );

    if (!workspaceLoaded) {
      return const _HomeEntryPlaceholder();
    }

    if (isDesktopTargetPlatform()) {
      final override = debugClassicScreenBuilderOverride;
      return override != null ? override(context) : const HomeScreen();
    }

    if (homeNavigationPreferences.mode == HomeNavigationMode.bottomBar) {
      final override = debugBottomNavShellBuilderOverride;
      return override != null ? override(context) : const HomeBottomNavShell();
    }

    final override = debugClassicScreenBuilderOverride;
    return override != null ? override(context) : const HomeScreen();
  }
}

class _HomeEntryPlaceholder extends StatelessWidget {
  const _HomeEntryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const SizedBox.expand(),
    );
  }
}
