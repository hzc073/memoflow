import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import '../../core/drawer_navigation.dart';
import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../home/app_drawer.dart';
import '../home/app_drawer_destination_builder.dart';
import '../home/desktop/desktop_destination_shell.dart';
import '../home/home_entry_screen.dart';
import '../home/home_navigation_host.dart';
import '../memos/memos_list_screen.dart';
import '../settings/about_us_screen.dart';
import '../../i18n/strings.g.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({
    super.key,
    this.presentation = HomeScreenPresentation.standalone,
    this.embeddedNavigationHost,
  });

  final HomeScreenPresentation presentation;
  final HomeEmbeddedNavigationHost? embeddedNavigationHost;

  void _backToAllMemos(BuildContext context) {
    final host = embeddedNavigationHost;
    if (host != null) {
      host.handleBackToPrimaryDestination(context);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeEntryScreen()),
      (route) => false,
    );
  }

  void _navigate(BuildContext context, AppDrawerDestination dest) {
    final host = embeddedNavigationHost;
    if (host != null) {
      host.handleDrawerDestination(context, dest);
      return;
    }
    closeDrawerThenPushReplacement(
      context,
      buildDrawerDestinationScreen(context: context, destination: dest),
    );
  }

  void _openTag(BuildContext context, String tag) {
    final host = embeddedNavigationHost;
    if (host != null) {
      host.handleDrawerTag(context, tag);
      return;
    }
    closeDrawerThenPushReplacement(
      context,
      MemosListScreen(
        title: '#$tag',
        state: 'NORMAL',
        tag: tag,
        showDrawer: true,
        enableCompose: true,
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    openNotificationsDrawerDestination(
      context: context,
      navigationHost: embeddedNavigationHost,
      presentation: presentation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final platform = Theme.of(context).platform;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useDesktopSidePane = shouldUseDesktopSidePaneLayout(screenWidth);
    final isWindowsDesktop = platform == TargetPlatform.windows;
    final desktopNavigationMode = useDesktopSidePane
        ? DesktopTitlebarNavigationMode.expandedSidebar
        : DesktopTitlebarNavigationMode.hidden;
    const desktopNavigationContext =
        DesktopTitlebarNavigationContext.topLevelDestination;
    final omitTopLevelChrome = shouldOmitDesktopTopLevelChrome(
      platform: platform,
      navigationMode: desktopNavigationMode,
      navigationContext: desktopNavigationContext,
    );
    final enableWindowsDragToMove = isWindowsDesktop;
    final useEmbeddedBottomNav =
        presentation == HomeScreenPresentation.embeddedBottomNav;
    final drawerPanel = AppDrawer(
      selected: AppDrawerDestination.about,
      onSelect: (d) => _navigate(context, d),
      onSelectTag: (t) => _openTag(context, t),
      onOpenNotifications: () => _openNotifications(context),
      embedded: useDesktopSidePane,
    );
    final pageBody = const AboutUsContent();
    return PopScope(
      canPop: useEmbeddedBottomNav,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || useEmbeddedBottomNav) return;
        _backToAllMemos(context);
      },
      child: DesktopDestinationShell(
        selectedDestination: AppDrawerDestination.about,
        onSelectDestination: (d) => _navigate(context, d),
        onSelectTag: (t) => _openTag(context, t),
        onOpenNotifications: () => _openNotifications(context),
        backgroundColor: bg,
        title: Text(
          context.t.strings.legacy.msg_about,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        body: pageBody,
        fallback: Scaffold(
          backgroundColor: bg,
          drawer: useDesktopSidePane ? null : drawerPanel,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: resolveDesktopTopLevelToolbarHeight(
              platform: platform,
              navigationMode: desktopNavigationMode,
              navigationContext: desktopNavigationContext,
            ),
            flexibleSpace: enableWindowsDragToMove
                ? const DragToMoveArea(child: SizedBox.expand())
                : null,
            automaticallyImplyLeading: !omitTopLevelChrome,
            leading: resolveDesktopTopLevelLeading(
              platform: platform,
              navigationMode: desktopNavigationMode,
              navigationContext: desktopNavigationContext,
              leading: IconButton(
                tooltip: context.t.strings.legacy.msg_back,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _backToAllMemos(context),
              ),
            ),
            title: resolveDesktopTopLevelTitle(
              platform: platform,
              navigationMode: desktopNavigationMode,
              navigationContext: desktopNavigationContext,
              title: IgnorePointer(
                ignoring: enableWindowsDragToMove,
                child: Text(context.t.strings.legacy.msg_about),
              ),
            ),
            centerTitle: false,
          ),
          body: useDesktopSidePane
              ? Row(
                  children: [
                    SizedBox(
                      width: kMemoFlowDesktopDrawerWidth,
                      child: drawerPanel,
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    Expanded(child: pageBody),
                  ],
                )
              : pageBody,
        ),
      ),
    );
  }
}
