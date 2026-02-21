import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/app_localization.dart';
import '../../core/desktop_settings_window.dart';
import '../../core/desktop_shortcuts.dart';
import '../../core/memoflow_palette.dart';
import '../../core/url.dart';
import '../../state/local_library_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
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
import 'desktop_shortcuts_settings_screen.dart';
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
  });

  final VoidCallback? onRequestClose;
  final bool showAppBar;
  final bool enableDragToMove;

  static final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  void _close(BuildContext context) {
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
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
      ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enableWindowsDragToMove =
        Theme.of(context).platform == TargetPlatform.windows;
    final enableAppBarDragToMove = enableDragToMove || enableWindowsDragToMove;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final versionStyle = TextStyle(fontSize: 11, color: textMuted);
    final hapticsEnabled = ref.watch(
      appPreferencesProvider.select((p) => p.hapticsEnabled),
    );
    final supporterCrownEnabled = ref.watch(
      appPreferencesProvider.select((p) => p.supporterCrownEnabled),
    );

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close(context);
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: showAppBar
            ? AppBar(
                flexibleSpace: enableAppBarDragToMove
                    ? const DragToMoveArea(child: SizedBox.expand())
                    : null,
                leading: IconButton(
                  tooltip: context.t.strings.legacy.msg_close,
                  icon: const Icon(Icons.close),
                  onPressed: () => _close(context),
                ),
                title: IgnorePointer(
                  ignoring: enableAppBarDragToMove,
                  child: Text(context.t.strings.legacy.msg_settings),
                ),
                centerTitle: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              )
            : null,
        body: Stack(
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
              padding: EdgeInsets.fromLTRB(16, showAppBar ? 8 : 16, 16, 88),
              children: [
                _ProfileCard(
                  card: card,
                  textMain: textMain,
                  textMuted: textMuted,
                  name: name,
                  subtitle: subtitle,
                  avatarUrl: avatarUrl,
                  showCrown: supporterCrownEnabled,
                  onTap: () {
                    haptic();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccountSecurityScreen(),
                      ),
                    );
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
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const StatsScreen(),
                            ),
                          );
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
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const WidgetsScreen(),
                            ),
                          );
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
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ApiPluginsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _CardGroup(
                  card: card,
                  divider: divider,
                  children: [
                    _SettingRow(
                      icon: Icons.menu_book_outlined,
                      label: context.t.strings.legacy.msg_user_guide,
                      textMain: textMain,
                      textMuted: textMuted,
                      onTap: () {
                        haptic();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const UserGuideScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _CardGroup(
                  card: card,
                  divider: divider,
                  children: [
                    _SettingRow(
                      icon: Icons.person_outline,
                      label: context.t.strings.legacy.msg_account_security,
                      textMain: textMain,
                      textMuted: textMuted,
                      onTap: () {
                        haptic();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AccountSecurityScreen(),
                          ),
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
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PreferencesSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    if (isDesktopShortcutEnabled())
                      _SettingRow(
                        icon: Icons.keyboard_command_key,
                        label: '快捷键',
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const DesktopShortcutsSettingsScreen(),
                            ),
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
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AiSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _SettingRow(
                      icon: Icons.lock_outline,
                      label: context.t.strings.legacy.msg_app_lock,
                      textMain: textMain,
                      textMuted: textMuted,
                      onTap: () {
                        haptic();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PasswordLockScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _CardGroup(
                  card: card,
                  divider: divider,
                  children: [
                    _SettingRow(
                      icon: Icons.science_outlined,
                      label: context.t.strings.legacy.msg_laboratory,
                      textMain: textMain,
                      textMuted: textMuted,
                      onTap: () {
                        haptic();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LaboratoryScreen(),
                          ),
                        );
                      },
                    ),
                    _SettingRow(
                      icon: Icons.extension_outlined,
                      label: context.t.strings.legacy.msg_components,
                      textMain: textMain,
                      textMuted: textMuted,
                      onTap: () {
                        haptic();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ComponentsSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _CardGroup(
                  card: card,
                  divider: divider,
                  children: [
                    _SettingRow(
                      icon: Icons.chat_bubble_outline,
                      label: context.t.strings.legacy.msg_feedback,
                      textMain: textMain,
                      textMuted: textMuted,
                      onTap: () {
                        haptic();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FeedbackScreen(),
                          ),
                        );
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
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ImportExportScreen(),
                          ),
                        );
                      },
                    ),
                    _SettingRow(
                      icon: Icons.info_outline,
                      label: context.t.strings.legacy.msg_about,
                      textMain: textMain,
                      textMuted: textMuted,
                      onTap: () {
                        haptic();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AboutUsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
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
          ],
        ),
      ),
    );
  }
}

class _CardGroup extends StatelessWidget {
  const _CardGroup({
    required this.card,
    required this.divider,
    required this.children,
  });

  final Color card;
  final Color divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, color: divider),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.textMain,
    required this.textMuted,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color textMain;
  final Color textMuted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: textMuted),
            ],
          ),
        ),
      ),
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
    required this.showCrown,
    required this.onTap,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String name;
  final String subtitle;
  final String avatarUrl;
  final bool showCrown;
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
    if (showCrown) {
      final badgeColor = isDark
          ? const Color(0xFFF2C879)
          : const Color(0xFFE1A670);
      final badgeBg = isDark ? const Color(0xFF2C2520) : Colors.white;
      avatarWidget = SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: avatarWidget),
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: badgeBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor.withValues(alpha: 0.8)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  size: 12,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      );
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
