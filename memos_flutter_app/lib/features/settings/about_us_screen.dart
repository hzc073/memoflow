import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/legal/legal_consent_policy.dart';
import '../../i18n/strings.g.dart';
import '../../platform/platform_route.dart';
import '../debug/debug_tools_screen.dart';
import '../updates/donors_wall_screen.dart';
import '../updates/release_notes_screen.dart';
import 'settings_ui.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  static final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      showBackButton: showBackButton,
      title: Text(context.t.strings.legacy.msg_about),
      children: const [AboutUsContent()],
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
    Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => const DebugToolsScreen(),
      ),
    );
  }

  Future<void> _openExternalLink(BuildContext context, String rawUrl) async {
    final uri = Uri.parse(rawUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_unable_open_browser_try),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_failed_open_try)),
      );
    }
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
    final tokens = settingsPageTokens(context);
    const websiteUrl = 'https://memoflow.hzc073.com/';
    const helpUrl = 'https://memoflow.hzc073.com/help/';
    const feedbackUrl = 'https://github.com/hzc073/memoflow/issues';
    final entries = <_AboutEntry>[
      _AboutEntry(
        icon: Icons.public_outlined,
        title: context.t.strings.legacy.msg_about_website_link,
        subtitle: context.t.strings.legacy.msg_about_website_link_subtitle,
        external: true,
        onTap: () => _openExternalLink(context, websiteUrl),
      ),
      _AboutEntry(
        icon: Icons.privacy_tip_outlined,
        title: context.t.strings.legacy.msg_about_privacy_policy,
        subtitle: context.t.strings.legacy.msg_about_privacy_policy_subtitle,
        external: true,
        onTap: () => _openExternalLink(
          context,
          MemoFlowLegalConsentPolicy.privacyPolicyUrl,
        ),
      ),
      _AboutEntry(
        icon: Icons.description_outlined,
        title: context.t.strings.legacy.msg_about_user_agreement,
        subtitle: context.t.strings.legacy.msg_about_user_agreement_subtitle,
        external: true,
        onTap: () => _openExternalLink(
          context,
          MemoFlowLegalConsentPolicy.termsOfServiceUrl,
        ),
      ),
      _AboutEntry(
        icon: Icons.help_outline,
        title: context.t.strings.legacy.msg_about_help_center,
        subtitle: context.t.strings.legacy.msg_about_help_center_subtitle,
        external: true,
        onTap: () => _openExternalLink(context, helpUrl),
      ),
      _AboutEntry(
        icon: Icons.update_outlined,
        title: context.t.strings.legacy.msg_release_notes_2,
        subtitle: context.t.strings.legacy.msg_about_release_notes_subtitle,
        onTap: () {
          Navigator.of(context).push(
            buildPlatformPageRoute<void>(
              context: context,
              builder: (_) => const ReleaseNotesScreen(),
            ),
          );
        },
      ),
      _AboutEntry(
        icon: Icons.feedback_outlined,
        title: context.t.strings.legacy.msg_about_submit_feedback,
        subtitle: context.t.strings.legacy.msg_about_submit_feedback_subtitle,
        external: true,
        onTap: () => _openExternalLink(context, feedbackUrl),
      ),
      _AboutEntry(
        icon: Icons.favorite_border,
        title: context.t.strings.legacy.msg_contributors,
        subtitle: context.t.strings.legacy.msg_about_contributors_subtitle,
        onTap: () {
          Navigator.of(context).push(
            buildPlatformPageRoute<void>(
              context: context,
              builder: (_) => const DonorsWallScreen(),
            ),
          );
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AboutSummary(
          onTap: _handleDebugTap,
          versionBuilder: (snapshot) =>
              _versionDescription(context, snapshot.data),
        ),
        const SizedBox(height: 16),
        SettingsSection(
          children: [
            for (final entry in entries)
              SettingsNavigationRow(
                leading: Icon(entry.icon, size: 20, color: tokens.textMuted),
                label: entry.title,
                description: entry.subtitle,
                trailingIcon: entry.external
                    ? Icons.open_in_new
                    : Icons.chevron_right,
                onTap: entry.onTap,
              ),
          ],
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 10),
          Text(
            context.t.strings.legacy.msg_debug_tap_logo_enter_debug_tools,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: tokens.textMuted),
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

class _AboutSummary extends StatelessWidget {
  const _AboutSummary({required this.onTap, required this.versionBuilder});

  final VoidCallback onTap;
  final String Function(AsyncSnapshot<PackageInfo> snapshot) versionBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return GestureDetector(
      onTap: onTap,
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
          const SettingsContentHeader(
            title: 'MemoFlow',
            textAlign: TextAlign.center,
            prominent: true,
          ),
          const SizedBox(height: 6),
          FutureBuilder<PackageInfo>(
            future: AboutUsScreen._packageInfoFuture,
            builder: (context, snapshot) {
              return Text(
                versionBuilder(snapshot),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: tokens.textMuted,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AboutEntry {
  const _AboutEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.external = false,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool external;
  final VoidCallback onTap;
}
