import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/app_localization.dart';
import '../../application/desktop/desktop_settings_window.dart';
import '../../core/drawer_navigation.dart';
import '../../core/platform_layout.dart';
import '../../core/url.dart';
import '../../platform/platform_icons.dart';
import '../../platform/platform_route.dart';
import '../../platform/platform_target.dart';
import '../../platform/widgets/platform_adaptive_layout.dart';
import '../../platform/widgets/platform_page.dart';
import '../../private_hooks/private_extension_bundle_provider.dart';
import '../../state/system/local_library_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/system/session_provider.dart';
import '../home/app_drawer.dart';
import '../home/app_drawer_destination_builder.dart';
import '../home/app_drawer_menu_button.dart';
import '../home/desktop/desktop_destination_shell.dart';
import '../home/home_entry_screen.dart';
import '../home/home_navigation_host.dart';
import '../memos/memos_list_screen.dart';
import '../stats/stats_screen.dart';
import 'about_us_screen.dart';
import 'account_security_screen.dart';
import 'ai_settings_screen.dart';
import 'api_plugins_screen.dart';
import 'components_settings_screen.dart';
import 'desktop_settings_screen.dart';
import 'feedback_screen.dart';
import 'import_export_screen.dart';
import 'laboratory_screen.dart';
import 'password_lock_screen.dart';
import 'preferences_settings_screen.dart';
import 'settings_ui.dart';
import 'support_memoflow_screen.dart';
import 'user_guide_screen.dart';
import 'widgets_screen.dart';
import '../../i18n/strings.g.dart';

class SettingsScreen extends ConsumerWidget
    implements DesktopSettingsWindowRouteIntent {
  const SettingsScreen({
    super.key,
    this.onRequestClose,
    this.showAppBar = true,
    this.enableDragToMove = false,
    this.presentation = HomeScreenPresentation.standalone,
    this.embeddedNavigationHost,
  });

  final VoidCallback? onRequestClose;
  final bool showAppBar;
  final bool enableDragToMove;
  final HomeScreenPresentation presentation;
  final HomeEmbeddedNavigationHost? embeddedNavigationHost;

  static final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  void _close(BuildContext context) {
    final host = embeddedNavigationHost;
    if (host != null) {
      host.handleBackToPrimaryDestination(context);
      return;
    }
    final closeCallback = onRequestClose;
    if (closeCallback != null) {
      closeCallback();
      return;
    }
    if (Navigator.of(context).canPop()) {
      context.safePop();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeEntryScreen()),
      (route) => false,
    );
  }

  String _resolveAvatarUrl(String rawUrl, Uri? baseUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('data:')) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return trimmed;
    }
    if (baseUrl == null) return trimmed;
    return joinBaseUrl(baseUrl, trimmed);
  }

  void _navigate(BuildContext context, AppDrawerDestination destination) {
    final host = embeddedNavigationHost;
    if (host != null) {
      host.handleDrawerDestination(context, destination);
      return;
    }
    closeDrawerThenPushReplacement(
      context,
      buildDrawerDestinationScreen(context: context, destination: destination),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final enableWindowsDragToMove =
        Theme.of(context).platform == TargetPlatform.windows;
    final enableAppBarDragToMove = enableDragToMove || enableWindowsDragToMove;
    final platformTarget = resolvePlatformTarget(context);
    final showDesktopSettings = isDesktopSettingsSupportedTarget(
      platformTarget,
    );
    final closeIcon =
        platformTarget == PlatformTarget.iPhone ||
            platformTarget == PlatformTarget.iPad
        ? PlatformIcons.close
        : Icons.close;
    final tokens = settingsPageTokens(context);
    final homeHierarchy = tokens.homeHierarchy;
    final bg = tokens.background;
    final textMain = tokens.textMain;
    final textMuted = tokens.textMuted;
    final versionStyle = TextStyle(fontSize: 11, color: textMuted);
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
    );
    final extensionEntries = [
      ...ref
          .watch(privateExtensionBundleProvider)
          .settingsEntries(context, ref),
    ]..sort((a, b) => a.order.compareTo(b.order));
    final useEmbeddedBottomNav =
        presentation == HomeScreenPresentation.embeddedBottomNav;
    final useDesktopSidePane =
        embeddedNavigationHost != null &&
        shouldUseDesktopSidePaneLayout(MediaQuery.sizeOf(context).width);
    final onSelectDay =
        shouldUseDesktopHomeUtilityDestination(
          context: context,
          presentation: presentation,
          navigationHost: embeddedNavigationHost,
        )
        ? (DateTime day) => openDesktopHomeDayFilterDestination(
            context: context,
            day: day,
            presentation: presentation,
            navigationHost: embeddedNavigationHost,
          )
        : null;
    final drawerPanel = useEmbeddedBottomNav
        ? AppDrawer(
            selected: AppDrawerDestination.settings,
            onSelect: (destination) => _navigate(context, destination),
            onSelectTag: (tag) => _openTag(context, tag),
            onOpenNotifications: () => _openNotifications(context),
            embedded: false,
          )
        : null;

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    void pushSettingsPage(WidgetBuilder builder) {
      Navigator.of(
        context,
      ).push(buildPlatformPageRoute<void>(context: context, builder: builder));
    }

    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final localLibrary = ref.watch(currentLocalLibraryProvider);
    final name = localLibrary?.name.isNotEmpty == true
        ? localLibrary!.name
        : (account?.user.displayName.isNotEmpty ?? false)
        ? account!.user.displayName
        : (account?.user.name.isNotEmpty ?? false)
        ? account!.user.name
        : 'MemoFlow';
    final description = (account?.user.description ?? '').trim();
    final subtitle = localLibrary != null
        ? localLibrary.locationLabel
        : description.isNotEmpty
        ? description
        : context.t.strings.legacy.msg_capture_every_moment_record;
    final avatarUrl = localLibrary != null
        ? ''
        : _resolveAvatarUrl((account?.user.avatarUrl ?? ''), account?.baseUrl);

    final pageBody = Stack(
      children: [
        if (tokens.isDark)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFF0B0B0B), bg, bg],
                ),
              ),
            ),
          ),
        ListView(
          children: [
            PlatformBoundedContent(
              desktopMaxWidth: 760,
              tabletMaxWidth: 680,
              padding: EdgeInsets.fromLTRB(16, showAppBar ? 8 : 16, 16, 88),
              child: Column(
                key: const ValueKey<String>('settings.boundedContent'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsHomeProfileEntry(
                    avatar: _SettingsAvatar(
                      avatarUrl: avatarUrl,
                      iconColor: textMuted,
                    ),
                    name: name,
                    subtitle: subtitle,
                    onTap: () {
                      haptic();
                      pushSettingsPage((_) => const AccountSecurityScreen());
                    },
                  ),
                  SizedBox(height: homeHierarchy.sectionSpacing),
                  Row(
                    children: [
                      Expanded(
                        child: SettingsHomeShortcutTile(
                          icon: Icons.calendar_month_outlined,
                          label: context.t.strings.legacy.msg_stats,
                          onTap: () {
                            haptic();
                            pushSettingsPage((_) => const StatsScreen());
                          },
                        ),
                      ),
                      SizedBox(width: homeHierarchy.shortcutSpacing),
                      Expanded(
                        child: SettingsHomeShortcutTile(
                          icon: Icons.widgets_outlined,
                          label: context.t.strings.legacy.msg_widgets,
                          onTap: () {
                            haptic();
                            pushSettingsPage((_) => const WidgetsScreen());
                          },
                        ),
                      ),
                      SizedBox(width: homeHierarchy.shortcutSpacing),
                      Expanded(
                        child: SettingsHomeShortcutTile(
                          icon: Icons.code,
                          label: context.t.strings.legacy.msg_api_plugins,
                          onTap: () {
                            haptic();
                            pushSettingsPage((_) => const ApiPluginsScreen());
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: homeHierarchy.sectionSpacing),
                  SettingsHomeSection(
                    children: [
                      SettingsNavigationRow(
                        leading: Icon(
                          Icons.menu_book_outlined,
                          size: 20,
                          color: textMuted,
                        ),
                        label: context.t.strings.legacy.msg_user_guide,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const UserGuideScreen());
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: homeHierarchy.sectionSpacing),
                  SettingsHomeSection(
                    children: [
                      SettingsNavigationRow(
                        leading: Icon(
                          Icons.person_outline,
                          size: 20,
                          color: textMuted,
                        ),
                        label: context.t.strings.legacy.msg_account_security,
                        onTap: () {
                          haptic();
                          pushSettingsPage(
                            (_) => const AccountSecurityScreen(),
                          );
                        },
                      ),
                      SettingsNavigationRow(
                        leading: Icon(Icons.tune, size: 20, color: textMuted),
                        label: context.t.strings.legacy.msg_preferences,
                        onTap: () {
                          haptic();
                          pushSettingsPage(
                            (_) => const PreferencesSettingsScreen(),
                          );
                        },
                      ),
                      if (showDesktopSettings)
                        SettingsNavigationRow(
                          leading: Icon(
                            Icons.devices_outlined,
                            size: 20,
                            color: textMuted,
                          ),
                          label: context.t.strings.legacy.msg_desktop_settings,
                          onTap: () {
                            haptic();
                            pushSettingsPage(
                              (_) => const DesktopSettingsScreen(),
                            );
                          },
                        ),
                      SettingsNavigationRow(
                        leading: Icon(
                          Icons.smart_toy_outlined,
                          size: 20,
                          color: textMuted,
                        ),
                        label: context.t.strings.legacy.msg_ai_settings,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const AiSettingsScreen());
                        },
                      ),
                      SettingsNavigationRow(
                        leading: Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: textMuted,
                        ),
                        label: context.t.strings.legacy.msg_app_lock,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const PasswordLockScreen());
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: homeHierarchy.sectionSpacing),
                  SettingsHomeSection(
                    children: [
                      SettingsNavigationRow(
                        leading: Icon(
                          Icons.science_outlined,
                          size: 20,
                          color: textMuted,
                        ),
                        label: context.t.strings.legacy.msg_laboratory,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const LaboratoryScreen());
                        },
                      ),
                      SettingsNavigationRow(
                        leading: Icon(
                          Icons.extension_outlined,
                          size: 20,
                          color: textMuted,
                        ),
                        label: context.t.strings.legacy.msg_components,
                        onTap: () {
                          haptic();
                          pushSettingsPage(
                            (_) => const ComponentsSettingsScreen(),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: homeHierarchy.sectionSpacing),
                  SettingsHomeSection(
                    children: [
                      SettingsNavigationRow(
                        leading: Icon(
                          Icons.help_outline,
                          size: 20,
                          color: textMuted,
                        ),
                        label: context.t.strings.legacy.msg_help_diagnostics,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const FeedbackScreen());
                        },
                      ),
                      SettingsNavigationRow(
                        leading: Icon(
                          Icons.favorite_border,
                          size: 20,
                          color: textMuted,
                        ),
                        label: context.tr(
                          zh: '支持 MemoFlow',
                          en: 'Support MemoFlow',
                        ),
                        onTap: () {
                          haptic();
                          pushSettingsPage(
                            (_) => const SupportMemoFlowScreen(),
                          );
                        },
                      ),
                      SettingsNavigationRow(
                        leading: Icon(
                          Icons.import_export,
                          size: 20,
                          color: textMuted,
                        ),
                        label: context.t.strings.legacy.msg_import_export,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const ImportExportScreen());
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: homeHierarchy.sectionSpacing),
                  SettingsHomeSection(
                    children: [
                      SettingsNavigationRow(
                        leading: Icon(
                          Icons.info_outline,
                          size: 20,
                          color: textMuted,
                        ),
                        label: context.t.strings.legacy.msg_about,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const AboutUsScreen());
                        },
                      ),
                    ],
                  ),
                  if (extensionEntries.isNotEmpty) ...[
                    SizedBox(height: homeHierarchy.sectionSpacing),
                    SettingsHomeSection(
                      children: [
                        ...extensionEntries.map(
                          (entry) => SettingsNavigationRow(
                            leading: Icon(
                              entry.icon,
                              size: 20,
                              color: textMuted,
                            ),
                            label: entry.titleBuilder(context),
                            description: entry.subtitleBuilder?.call(context),
                            onTap: () {
                              haptic();
                              entry.onTap();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Column(
                    children: [
                      FutureBuilder<PackageInfo>(
                        future: _packageInfoFuture,
                        builder: (context, snapshot) {
                          final version = snapshot.data?.version.trim() ?? '';
                          final label = version.isEmpty
                              ? context.t.strings.legacy.msg_version
                              : context.t.strings.legacy.msg_version_v(
                                  version: version,
                                );
                          return Text(label, style: versionStyle);
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t.strings.legacy.msg_made_love_note_taking,
                        style: versionStyle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    final platformPage = PlatformPage(
      backgroundColor: bg,
      drawer: drawerPanel,
      drawerEnableOpenDragGesture: !useEmbeddedBottomNav,
      desktopNavigationMode: useDesktopSidePane
          ? DesktopTitlebarNavigationMode.expandedSidebar
          : DesktopTitlebarNavigationMode.hidden,
      desktopNavigationContext:
          DesktopTitlebarNavigationContext.topLevelDestination,
      leading: showAppBar
          ? (useEmbeddedBottomNav
                ? AppDrawerMenuButton(
                    tooltip: context.t.strings.legacy.msg_toggle_sidebar,
                    iconColor: textMain,
                    badgeBorderColor: bg,
                  )
                : IconButton(
                    tooltip: context.t.strings.legacy.msg_close,
                    icon: Icon(closeIcon),
                    onPressed: () => _close(context),
                  ))
          : null,
      title: showAppBar
          ? IgnorePointer(
              ignoring: enableAppBarDragToMove,
              child: Text(context.t.strings.legacy.msg_settings),
            )
          : null,
      toolbar: enableAppBarDragToMove
          ? const DragToMoveArea(child: SizedBox(height: 0))
          : null,
      body: pageBody,
    );

    return PopScope(
      canPop: useEmbeddedBottomNav,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || useEmbeddedBottomNav) return;
        _close(context);
      },
      child: showAppBar
          ? DesktopDestinationShell(
              selectedDestination: AppDrawerDestination.settings,
              onSelectDestination: (destination) =>
                  _navigate(context, destination),
              onSelectTag: (tag) => _openTag(context, tag),
              onSelectDay: onSelectDay,
              onOpenNotifications: () => _openNotifications(context),
              backgroundColor: bg,
              title: Text(
                context.t.strings.legacy.msg_settings,
                overflow: TextOverflow.ellipsis,
              ),
              dismissalIntent: useEmbeddedBottomNav
                  ? null
                  : DesktopDestinationDismissalIntent(
                      tooltip: context.t.strings.legacy.msg_close,
                      icon: closeIcon,
                      onPressed: () => _close(context),
                    ),
              body: pageBody,
              fallback: platformPage,
            )
          : platformPage,
    );
  }
}

class _SettingsAvatar extends StatefulWidget {
  const _SettingsAvatar({required this.avatarUrl, required this.iconColor});

  final String avatarUrl;
  final Color iconColor;

  @override
  State<_SettingsAvatar> createState() => _SettingsAvatarState();
}

class _SettingsAvatarState extends State<_SettingsAvatar> {
  static const int _maxCachedDataUriAvatars = 4;
  static final Map<String, Uint8List?> _dataUriAvatarCache =
      <String, Uint8List?>{};

  bool _isDataUri = false;
  Uint8List? _dataUriBytes;

  @override
  void initState() {
    super.initState();
    _resolveDataUriAvatar();
  }

  @override
  void didUpdateWidget(covariant _SettingsAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _resolveDataUriAvatar();
    }
  }

  void _resolveDataUriAvatar() {
    final avatarUrl = widget.avatarUrl.trim();
    _isDataUri = avatarUrl.startsWith('data:');
    if (!_isDataUri) {
      _dataUriBytes = null;
      return;
    }
    if (_dataUriAvatarCache.containsKey(avatarUrl)) {
      _dataUriBytes = _dataUriAvatarCache[avatarUrl];
      return;
    }

    _dataUriBytes = _tryDecodeDataUri(avatarUrl);
    _dataUriAvatarCache[avatarUrl] = _dataUriBytes;
    if (_dataUriAvatarCache.length > _maxCachedDataUriAvatars) {
      _dataUriAvatarCache.remove(_dataUriAvatarCache.keys.first);
    }
  }

  static Uint8List? _tryDecodeDataUri(String raw) {
    final index = raw.indexOf('base64,');
    if (index == -1) return null;
    final data = raw.substring(index + 'base64,'.length).trim();
    if (data.isEmpty) return null;
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }

  Widget _buildFallback(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerHighest,
      ),
      child: Icon(Icons.person, color: widget.iconColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.avatarUrl.trim();
    final avatarFallback = _buildFallback(context);

    if (avatarUrl.isEmpty) return avatarFallback;
    if (_isDataUri) {
      final bytes = _dataUriBytes;
      if (bytes == null) return avatarFallback;
      return ClipOval(
        child: Image.memory(
          bytes,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => avatarFallback,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (_, _) => avatarFallback,
        errorWidget: (_, _, _) => avatarFallback,
      ),
    );
  }
}
