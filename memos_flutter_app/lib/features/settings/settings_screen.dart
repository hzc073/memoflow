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
import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../../core/url.dart';
import '../../platform/platform_icons.dart';
import '../../platform/platform_route.dart';
import '../../platform/platform_target.dart';
import '../../platform/widgets/platform_adaptive_layout.dart';
import '../../platform/widgets/platform_list_section.dart';
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
import 'donation_dialog.dart';
import 'feedback_screen.dart';
import 'import_export_screen.dart';
import 'laboratory_screen.dart';
import 'password_lock_screen.dart';
import 'preferences_settings_screen.dart';
import 'user_guide_screen.dart';
import 'windows_related_settings_screen.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enableWindowsDragToMove =
        Theme.of(context).platform == TargetPlatform.windows;
    final isWindowsDesktop =
        Theme.of(context).platform == TargetPlatform.windows;
    final enableAppBarDragToMove = enableDragToMove || enableWindowsDragToMove;
    final platformTarget = resolvePlatformTarget(context);
    final closeIcon =
        platformTarget == PlatformTarget.iPhone ||
            platformTarget == PlatformTarget.iPad
        ? PlatformIcons.close
        : Icons.close;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
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
        if (isDark)
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
                  _ProfileCard(
                    card: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    name: name,
                    subtitle: subtitle,
                    avatarUrl: avatarUrl,
                    onTap: () {
                      haptic();
                      pushSettingsPage((_) => const AccountSecurityScreen());
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ShortcutTile(
                          card: card,
                          textMain: textMain,
                          textMuted: textMuted,
                          icon: Icons.calendar_month_outlined,
                          label: context.t.strings.legacy.msg_stats,
                          onTap: () {
                            haptic();
                            pushSettingsPage((_) => const StatsScreen());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ShortcutTile(
                          card: card,
                          textMain: textMain,
                          textMuted: textMuted,
                          icon: Icons.widgets_outlined,
                          label: context.t.strings.legacy.msg_widgets,
                          onTap: () {
                            haptic();
                            pushSettingsPage((_) => const WidgetsScreen());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ShortcutTile(
                          card: card,
                          textMain: textMain,
                          textMuted: textMuted,
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
                  const SizedBox(height: 14),
                  _CardGroup(
                    children: [
                      _SettingRow(
                        icon: Icons.menu_book_outlined,
                        label: context.t.strings.legacy.msg_user_guide,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const UserGuideScreen());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CardGroup(
                    children: [
                      _SettingRow(
                        icon: Icons.person_outline,
                        label: context.t.strings.legacy.msg_account_security,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          pushSettingsPage(
                            (_) => const AccountSecurityScreen(),
                          );
                        },
                      ),
                      _SettingRow(
                        icon: Icons.tune,
                        label: context.t.strings.legacy.msg_preferences,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          pushSettingsPage(
                            (_) => const PreferencesSettingsScreen(),
                          );
                        },
                      ),
                      if (isWindowsDesktop)
                        _SettingRow(
                          icon: Icons.desktop_windows_outlined,
                          label: context
                              .t
                              .strings
                              .legacy
                              .msg_windows_related_settings,
                          textMain: textMain,
                          textMuted: textMuted,
                          onTap: () {
                            haptic();
                            pushSettingsPage(
                              (_) => const WindowsRelatedSettingsScreen(),
                            );
                          },
                        ),
                      _SettingRow(
                        icon: Icons.smart_toy_outlined,
                        label: context.t.strings.legacy.msg_ai_settings,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const AiSettingsScreen());
                        },
                      ),
                      _SettingRow(
                        icon: Icons.lock_outline,
                        label: context.t.strings.legacy.msg_app_lock,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const PasswordLockScreen());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CardGroup(
                    children: [
                      _SettingRow(
                        icon: Icons.science_outlined,
                        label: context.t.strings.legacy.msg_laboratory,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const LaboratoryScreen());
                        },
                      ),
                      _SettingRow(
                        icon: Icons.extension_outlined,
                        label: context.t.strings.legacy.msg_components,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          pushSettingsPage(
                            (_) => const ComponentsSettingsScreen(),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CardGroup(
                    children: [
                      _SettingRow(
                        icon: Icons.chat_bubble_outline,
                        label: context.t.strings.legacy.msg_feedback,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const FeedbackScreen());
                        },
                      ),
                      _SettingRow(
                        icon: Icons.bolt_outlined,
                        label: context.t.strings.legacy.msg_charging_station,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          DonationDialog.show(context);
                        },
                      ),
                      _SettingRow(
                        icon: Icons.import_export,
                        label: context.t.strings.legacy.msg_import_export,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const ImportExportScreen());
                        },
                      ),
                      _SettingRow(
                        icon: Icons.info_outline,
                        label: context.t.strings.legacy.msg_about,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          pushSettingsPage((_) => const AboutUsScreen());
                        },
                      ),
                    ],
                  ),
                  if (extensionEntries.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _CardGroup(
                      children: [
                        ...extensionEntries.map(
                          (entry) => _SettingRow(
                            icon: entry.icon,
                            label: entry.titleBuilder(context),
                            subtitle: entry.subtitleBuilder?.call(context),
                            textMain: textMain,
                            textMuted: textMuted,
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

class _CardGroup extends StatelessWidget {
  const _CardGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PlatformListSection(padding: EdgeInsets.zero, children: children);
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.textMain,
    required this.textMuted,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color textMain;
  final Color textMuted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final normalizedSubtitle = subtitle?.trim();
    return PlatformListSectionRow(
      leading: Icon(icon, size: 20, color: textMuted),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
      ),
      subtitle: normalizedSubtitle == null || normalizedSubtitle.isEmpty
          ? null
          : Text(
              normalizedSubtitle,
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
      trailing: Icon(PlatformIcons.chevronForward, size: 18, color: textMuted),
      onTap: onTap,
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.name,
    required this.subtitle,
    required this.avatarUrl,
    required this.onTap,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String name;
  final String subtitle;
  final String avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarFallback = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
      ),
      child: Icon(Icons.person, color: textMuted),
    );
    Widget avatarWidget = avatarFallback;
    if (avatarUrl.trim().isNotEmpty) {
      if (avatarUrl.startsWith('data:')) {
        final bytes = _tryDecodeDataUri(avatarUrl);
        if (bytes != null) {
          avatarWidget = ClipOval(
            child: Image.memory(
              bytes,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => avatarFallback,
            ),
          );
        }
      } else {
        avatarWidget = ClipOval(
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
          ),
          child: Row(
            children: [
              avatarWidget,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: textMuted),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
