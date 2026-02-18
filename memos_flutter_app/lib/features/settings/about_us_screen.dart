import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/memoflow_palette.dart';
import '../debug/debug_tools_screen.dart';
import '../updates/donors_wall_screen.dart';
import '../updates/release_notes_screen.dart';
import '../../i18n/strings.g.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.t.strings.legacy.msg_back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.t.strings.legacy.msg_about),
        centerTitle: false,
      ),
      body: const AboutUsContent(),
    );
  }
}

class AboutUsContent extends StatefulWidget {
  const AboutUsContent({super.key});

  @override
  State<AboutUsContent> createState() => _AboutUsContentState();
}

class _AboutUsContentState extends State<AboutUsContent> {
  int _debugTapCount = 0;
  DateTime? _lastDebugTapAt;

  void _handleDebugTap() {
    if (!kDebugMode) return;
    final now = DateTime.now();
    final last = _lastDebugTapAt;
    if (last == null ||
        now.difference(last) > const Duration(milliseconds: 1500)) {
      _debugTapCount = 0;
    }
    _debugTapCount++;
    _lastDebugTapAt = now;
    if (_debugTapCount < 5) return;
    _debugTapCount = 0;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DebugToolsScreen()));
  }

  void _showPlaceholderNotice(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(context.t.strings.legacy.msg_feature_in_progress)),
    );
  }

  String _versionDescription(BuildContext context, PackageInfo? info) {
    final version = info?.version.trim() ?? '';
    final buildNumber = info?.buildNumber.trim() ?? '';
    if (version.isEmpty) {
      return context.t.strings.legacy.msg_version_description_unknown;
    }
    if (buildNumber.isEmpty || buildNumber == version) {
      return context.t.strings.legacy.msg_version_description_v(
        version: version,
      );
    }
    return context.t.strings.legacy.msg_version_description_v_build(
      version: version,
      build: buildNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    final entries = <_AboutEntry>[
      _AboutEntry(
        icon: Icons.public_outlined,
        title: context.t.strings.legacy.msg_about_website_link,
        subtitle: context.t.strings.legacy.msg_about_website_link_subtitle,
        enabled: false,
        onTap: () => _showPlaceholderNotice(context),
      ),
      _AboutEntry(
        icon: Icons.privacy_tip_outlined,
        title: context.t.strings.legacy.msg_about_privacy_policy,
        subtitle: context.t.strings.legacy.msg_about_privacy_policy_subtitle,
        enabled: false,
        onTap: () => _showPlaceholderNotice(context),
      ),
      _AboutEntry(
        icon: Icons.description_outlined,
        title: context.t.strings.legacy.msg_about_user_agreement,
        subtitle: context.t.strings.legacy.msg_about_user_agreement_subtitle,
        enabled: false,
        onTap: () => _showPlaceholderNotice(context),
      ),
      _AboutEntry(
        icon: Icons.help_outline,
        title: context.t.strings.legacy.msg_about_help_center,
        subtitle: context.t.strings.legacy.msg_about_help_center_subtitle,
        enabled: false,
        onTap: () => _showPlaceholderNotice(context),
      ),
      _AboutEntry(
        icon: Icons.update_outlined,
        title: context.t.strings.legacy.msg_release_notes_2,
        subtitle: context.t.strings.legacy.msg_about_release_notes_subtitle,
        enabled: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ReleaseNotesScreen()),
          );
        },
      ),
      _AboutEntry(
        icon: Icons.feedback_outlined,
        title: context.t.strings.legacy.msg_about_submit_feedback,
        subtitle: context.t.strings.legacy.msg_about_submit_feedback_subtitle,
        enabled: false,
        onTap: () => _showPlaceholderNotice(context),
      ),
      _AboutEntry(
        icon: Icons.favorite_border,
        title: context.t.strings.legacy.msg_contributors,
        subtitle: context.t.strings.legacy.msg_about_contributors_subtitle,
        enabled: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DonorsWallScreen()),
          );
        },
      ),
    ];

    return Stack(
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            GestureDetector(
              onTap: _handleDebugTap,
              child: Column(
                children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: Image.asset(
                      'assets/splash/splash_logo_native.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'MemoFlow',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<PackageInfo>(
                    future: AboutUsScreen._packageInfoFuture,
                    builder: (context, snapshot) {
                      return Text(
                        _versionDescription(context, snapshot.data),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: textMuted,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _CardGroup(
              card: card,
              divider: divider,
              children: [
                for (final entry in entries)
                  _AboutEntryRow(
                    entry: entry,
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
              ],
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 10),
              Text(
                context.t.strings.legacy.msg_debug_tap_logo_enter_debug_tools,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: textMuted),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ],
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

class _AboutEntryRow extends StatelessWidget {
  const _AboutEntryRow({
    required this.entry,
    required this.textMain,
    required this.textMuted,
  });

  final _AboutEntry entry;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final statusColor = entry.enabled ? MemoFlowPalette.primary : textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: entry.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(entry.icon, size: 20, color: textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.subtitle,
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.enabled
                      ? context.t.strings.legacy.msg_status_available
                      : context.t.strings.legacy.msg_status_placeholder,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 20, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutEntry {
  const _AboutEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
}
