import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../core/desktop/window_chrome_safe_area.dart';
import '../platform_target.dart';

class PlatformPageDrawerController extends InheritedWidget {
  const PlatformPageDrawerController({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  static PlatformPageDrawerController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PlatformPageDrawerController>();
  }

  @override
  bool updateShouldNotify(PlatformPageDrawerController oldWidget) {
    return openDrawer != oldWidget.openDrawer;
  }
}

class PlatformPage extends StatelessWidget {
  const PlatformPage({
    super.key,
    required this.body,
    this.title,
    this.centerTitle,
    this.leading,
    this.actions,
    this.bottomBar,
    this.drawer,
    this.drawerEnableOpenDragGesture = true,
    this.sidebar,
    this.toolbar,
    this.safeArea = true,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.desktopNavigationMode,
    this.desktopNavigationContext,
    this.desktopWindowChromeSafeArea = false,
  });

  final Widget body;
  final Widget? title;
  final bool? centerTitle;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final Widget? drawer;
  final bool drawerEnableOpenDragGesture;
  final Widget? sidebar;
  final Widget? toolbar;
  final bool safeArea;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final DesktopTitlebarNavigationMode? desktopNavigationMode;
  final DesktopTitlebarNavigationContext? desktopNavigationContext;
  final bool desktopWindowChromeSafeArea;

  @override
  Widget build(BuildContext context) {
    final target = resolvePlatformTarget(context);
    final bodyWidget = safeArea ? SafeArea(child: body) : body;

    if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
      final appleBodyTextStyle = TextStyle(
        color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
        fontSize: 14,
        height: 1.35,
        decoration: TextDecoration.none,
      );
      final appleChromeTextStyle = appleBodyTextStyle.copyWith(
        fontSize: 17,
        height: 1.2,
      );
      final applePage = CupertinoPageScaffold(
        backgroundColor: backgroundColor,
        navigationBar:
            title == null && leading == null && (actions?.isEmpty ?? true)
            ? null
            : CupertinoNavigationBar(
                transitionBetweenRoutes: false,
                backgroundColor: backgroundColor,
                middle: title,
                leading: leading == null
                    ? null
                    : DefaultTextStyle.merge(
                        style: appleChromeTextStyle,
                        child: leading!,
                      ),
                trailing: actions == null
                    ? null
                    : DefaultTextStyle.merge(
                        style: appleChromeTextStyle,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions!,
                        ),
                      ),
              ),
        child: Column(
          children: [
            if (toolbar != null) toolbar!,
            Expanded(
              child: DefaultTextStyle.merge(
                style: appleBodyTextStyle,
                child: bodyWidget,
              ),
            ),
            if (bottomBar != null) bottomBar!,
          ],
        ),
      );
      if (drawer == null) {
        return applePage;
      }
      return Builder(
        builder: (drawerContext) {
          return PlatformPageDrawerController(
            openDrawer: () => _openAppleDrawer(drawerContext),
            child: applePage,
          );
        },
      );
    }

    final navigationContext =
        desktopNavigationContext ??
        resolveDesktopTitlebarNavigationContext(context);
    final navigationMode =
        desktopNavigationMode ?? DesktopTitlebarNavigationMode.hidden;
    final platform = switch (target) {
      PlatformTarget.macOS => TargetPlatform.macOS,
      PlatformTarget.windows => TargetPlatform.windows,
      PlatformTarget.linux => TargetPlatform.linux,
      _ => Theme.of(context).platform,
    };
    final effectiveTitle = resolveDesktopTopLevelTitle(
      platform: platform,
      navigationMode: navigationMode,
      navigationContext: navigationContext,
      title: title,
    );
    final topLevelChromeOmitted = shouldOmitDesktopTopLevelChrome(
      platform: platform,
      navigationMode: navigationMode,
      navigationContext: navigationContext,
    );
    final omitRouteDismissalControl = shouldOmitDesktopRouteDismissalControl(
      platform: platform,
      navigationContext: navigationContext,
    );
    final effectiveLeading = omitRouteDismissalControl || topLevelChromeOmitted
        ? null
        : leading;
    final automaticallyImplyLeading =
        !omitRouteDismissalControl && !topLevelChromeOmitted;
    final effectiveToolbarHeight = resolveDesktopTopLevelToolbarHeight(
      platform: platform,
      navigationMode: navigationMode,
      navigationContext: navigationContext,
    );
    final chromeInsets = resolveDesktopWindowChromeInsets(
      platform: platform,
      contentExtendsIntoTitleBar: desktopWindowChromeSafeArea,
    );
    final routeCanPop = ModalRoute.of(context)?.canPop ?? false;
    final needsChromeLeadingInset = chromeInsets.leading > 0;
    final impliedChromeLeading =
        needsChromeLeadingInset &&
            effectiveLeading == null &&
            automaticallyImplyLeading &&
            routeCanPop
        ? const BackButton()
        : null;
    final appBarLeadingChild = effectiveLeading ?? impliedChromeLeading;
    final appBarLeading = needsChromeLeadingInset && appBarLeadingChild != null
        ? DesktopWindowChromeSafeArea(
            contentExtendsIntoTitleBar: true,
            platform: platform,
            includeTop: false,
            includeTrailing: false,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: appBarLeadingChild,
            ),
          )
        : effectiveLeading;
    final appBarLeadingWidth =
        needsChromeLeadingInset && appBarLeadingChild != null
        ? kToolbarHeight + chromeInsets.leading
        : null;
    final appBarTitleSpacing =
        needsChromeLeadingInset && appBarLeadingChild == null
        ? NavigationToolbar.kMiddleSpacing + chromeInsets.leading
        : null;
    final appBarAutomaticallyImplyLeading = needsChromeLeadingInset
        ? false
        : automaticallyImplyLeading;

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar:
          !topLevelChromeOmitted &&
              effectiveTitle == null &&
              effectiveLeading == null &&
              (actions?.isEmpty ?? true)
          ? null
          : AppBar(
              toolbarHeight: effectiveToolbarHeight,
              title: effectiveTitle,
              centerTitle: centerTitle,
              leading: appBarLeading,
              leadingWidth: appBarLeadingWidth,
              titleSpacing: appBarTitleSpacing,
              automaticallyImplyLeading: appBarAutomaticallyImplyLeading,
              actions: actions,
            ),
      drawer: drawer,
      drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
      body: Column(
        children: [
          if (toolbar != null) toolbar!,
          Expanded(
            child: Row(
              children: [
                if (sidebar != null) sidebar!,
                Expanded(child: bodyWidget),
              ],
            ),
          ),
          if (bottomBar != null) bottomBar!,
        ],
      ),
    );
  }

  void _openAppleDrawer(BuildContext context) {
    final routeTextDirection = Directionality.of(context);
    final materialLocalizations = Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    );
    final barrierLabel =
        materialLocalizations?.modalBarrierDismissLabel ?? 'Dismiss';
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        barrierLabel: barrierLabel,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (routeContext, animation, secondaryAnimation) {
          return _ApplePlatformDrawerSurface(
            drawer: drawer!,
            backgroundColor: backgroundColor,
          );
        },
        transitionsBuilder:
            (routeContext, animation, secondaryAnimation, child) {
              final begin = routeTextDirection == TextDirection.rtl
                  ? const Offset(1, 0)
                  : const Offset(-1, 0);
              final position = Tween<Offset>(begin: begin, end: Offset.zero)
                  .animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  );
              return SlideTransition(position: position, child: child);
            },
      ),
    );
  }
}

class _ApplePlatformDrawerSurface extends StatelessWidget {
  const _ApplePlatformDrawerSurface({
    required this.drawer,
    required this.backgroundColor,
  });

  final Widget drawer;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(360.0, size.width * 0.88);
    final effectiveBackground =
        backgroundColor ??
        Theme.of(context).drawerTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SizedBox(
        width: width,
        height: size.height,
        child: Material(color: effectiveBackground, child: drawer),
      ),
    );
  }
}
