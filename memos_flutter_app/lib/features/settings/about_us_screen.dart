import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/memoflow_palette.dart';
import '../../data/updates/update_config.dart';
import '../../state/update_config_provider.dart';
import '../debug/debug_tools_screen.dart';
import '../updates/donors_wall_screen.dart';
import '../updates/update_announcement_dialog.dart';
import '../updates/version_announcement_dialog.dart';
import '../updates/release_notes_screen.dart';
import '../../i18n/strings.g.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
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

class AboutUsContent extends ConsumerStatefulWidget {
  const AboutUsContent({super.key});

  @override
  ConsumerState<AboutUsContent> createState() => _AboutUsContentState();
}

class _AboutUsContentState extends ConsumerState<AboutUsContent> {
  late final Future<UpdateAnnouncementConfig?> _updateConfigFuture;
  int _debugTapCount = 0;
  DateTime? _lastDebugTapAt;

  @override
  void initState() {
    super.initState();
    _updateConfigFuture = ref.read(updateConfigServiceProvider).fetchLatest();
  }

  Future<void> _showDebugAnnouncement(BuildContext context) async {
    final config = await ref.read(updateConfigServiceProvider).fetchLatest();
    if (!context.mounted) return;
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_failed_load_announcement_config,
          ),
        ),
      );
      return;
    }
    final info = await AboutUsScreen._packageInfoFuture;
    if (!context.mounted) return;
    final version = info.version.trim();
    await UpdateAnnouncementDialog.show(
      context,
      config: UpdateAnnouncementConfig(
        versionInfo: config.versionInfo,
        announcement: config.announcement,
        donors: config.donors,
        releaseNotes: config.releaseNotes,
        noticeEnabled: config.noticeEnabled,
        notice: config.notice,
        debugAnnouncement: config.debugAnnouncement,
        debugAnnouncementSource: DebugAnnouncementSource.releaseNotes,
      ),
      currentVersion: version,
    );
  }

  void _handleDebugTap() {
    if (!kDebugMode) return;
    final now = DateTime.now();
    final last = _lastDebugTapAt;
    if (last == null || now.difference(last) > const Duration(milliseconds: 1500)) {
      _debugTapCount = 0;
    }
    _debugTapCount++;
    _lastDebugTapAt = now;
    if (_debugTapCount < 5) return;
    _debugTapCount = 0;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DebugToolsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);

    return Stack(
      children: [
        if (isDark)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0B0B0B),
                    bg,
                    bg,
                  ],
                ),
              ),
            ),
          ),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            GestureDetector(
              onTap: _handleDebugTap,
              child: Container(
                padding: const EdgeInsets.all(16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MemoFlow', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textMain)),
                    const SizedBox(height: 8),
                    Text(
                      context.t.strings.legacy.msg_offline_first_client_memos_backend,
                      style: TextStyle(fontSize: 13, height: 1.4, color: textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _CardGroup(
              card: card,
              divider: divider,
              children: [
                _FeatureRow(
                  icon: Icons.cloud_sync_outlined,
                  title: context.t.strings.legacy.msg_offline_sync,
                  subtitle: context.t.strings.legacy.msg_local_db_outbox_queue,
                  textMain: textMain,
                  textMuted: textMuted,
                ),
                _FeatureRow(
                  icon: Icons.auto_awesome,
                  title: context.t.strings.legacy.msg_ai_reports,
                  subtitle: context.t.strings.legacy.msg_summaries_selected_range,
                  textMain: textMain,
                  textMuted: textMuted,
                ),
                _FeatureRow(
                  icon: Icons.graphic_eq,
                  title: context.t.strings.legacy.msg_voice_memos,
                  subtitle: context.t.strings.legacy.msg_record_create_memos_sync_later,
                  textMain: textMain,
                  textMuted: textMuted,
                ),
                _FeatureRow(
                  icon: Icons.search,
                  title: context.t.strings.legacy.msg_full_text_search,
                  subtitle: context.t.strings.legacy.msg_content_tags,
                  textMain: textMain,
                  textMuted: textMuted,
                ),
              ],
            ),
            FutureBuilder<PackageInfo>(
              future: AboutUsScreen._packageInfoFuture,
              builder: (context, snapshot) {
                final appVersion = snapshot.data?.version.trim() ?? '';
                return FutureBuilder<UpdateAnnouncementConfig?>(
                  future: _updateConfigFuture,
                  builder: (context, configSnapshot) {
                    final releaseNotes = configSnapshot.data?.releaseNotes ?? const <UpdateReleaseNoteEntry>[];
                    final resolvedEntry =
                        findVersionAnnouncementEntry(releaseNotes, appVersion) ??
                        VersionAnnouncementEntry(
                          version: appVersion,
                          dateLabel: '',
                          items: const [],
                        );
                    if (resolvedEntry.version.trim().isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          context.t.strings.legacy.msg_release_notes_2,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
                        ),
                        const SizedBox(height: 10),
                        _ReleaseNotesPreviewCard(
                          entry: resolvedEntry,
                          versionLabel: resolvedEntry.version,
                          card: card,
                          textMain: textMain,
                          textMuted: textMuted,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const ReleaseNotesScreen()),
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            FutureBuilder<UpdateAnnouncementConfig?>(
              future: _updateConfigFuture,
              builder: (context, snapshot) {
                final donors = snapshot.data?.donors ?? const <UpdateDonor>[];
                if (donors.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _CardGroup(
                      card: card,
                      divider: divider,
                      children: [
                        _LinkRow(
                          icon: Icons.favorite_border,
                          label: context.t.strings.legacy.msg_contributors,
                          textMain: textMain,
                          textMuted: textMuted,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const DonorsWallScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _LinkRow(
                    icon: Icons.bug_report_outlined,
                    label: context.t.strings.legacy.msg_debug_preview_update_dialog,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _showDebugAnnouncement(context),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Column(
              children: [
                FutureBuilder<PackageInfo>(
                  future: AboutUsScreen._packageInfoFuture,
                  builder: (context, snapshot) {
                    final version = snapshot.data?.version.trim() ?? '';
                    final label = version.isEmpty
                        ? context.t.strings.legacy.msg_version
                        : context.t.strings.legacy.msg_version_v(version: version);
                    return Text(label, style: TextStyle(fontSize: 11, color: textMuted));
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  context.t.strings.legacy.msg_made_love_note_taking,
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textMain,
    required this.textMuted,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontSize: 12, color: textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

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
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
              ),
              Icon(Icons.chevron_right, size: 20, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseNotesPreviewCard extends StatelessWidget {
  const _ReleaseNotesPreviewCard({
    required this.entry,
    required this.versionLabel,
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final VersionAnnouncementEntry entry;
  final String versionLabel;
  final Color card;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'v$versionLabel',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textMain),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 20, color: textMuted),
                ],
              ),
              const SizedBox(height: 8),
              if (entry.items.isEmpty)
                Text(
                  context.t.strings.legacy.msg_no_release_notes_yet,
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: textMuted),
                )
              else
                for (var i = 0; i < entry.items.length; i++) ...[
                  _ReleaseNotePreviewItem(
                    item: entry.items[i],
                    textMain: textMain,
                    textMuted: textMuted,
                    isDark: isDark,
                  ),
                  if (i != entry.items.length - 1) const SizedBox(height: 6),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseNotePreviewItem extends StatelessWidget {
  const _ReleaseNotePreviewItem({
    required this.item,
    required this.textMain,
    required this.textMuted,
    required this.isDark,
  });

  final VersionAnnouncementItem item;
  final Color textMain;
  final Color textMuted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final title = item.category.labelWithColon(context);
    final detail = item.localizedDetail(context);
    final accent = item.category.tone(isDark: isDark);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textMuted.withValues(alpha: 0.65),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 12.5, height: 1.35, color: textMain),
              children: [
                TextSpan(
                  text: title,
                  style: TextStyle(fontWeight: FontWeight.w700, color: accent),
                ),
                TextSpan(text: detail, style: TextStyle(color: textMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
