import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/updates/update_config.dart';
import 'donors_wall_screen.dart';
import 'version_announcement_dialog.dart';

enum AnnouncementAction {
  update,
  later,
  exitApp,
}

class UpdateAnnouncementDialog extends StatelessWidget {
  const UpdateAnnouncementDialog({
    super.key,
    required this.config,
    required this.currentVersion,
  });

  final UpdateAnnouncementConfig config;
  final String currentVersion;

  static Future<AnnouncementAction?> show(
    BuildContext context, {
    required UpdateAnnouncementConfig config,
    required String currentVersion,
  }) {
    return showGeneralDialog<AnnouncementAction>(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return UpdateAnnouncementDialog(
          config: config,
          currentVersion: currentVersion,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<bool> _launchDownload(BuildContext context, String rawUrl) async {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty || uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(zh: '无效的更新链接', en: 'Invalid download link'),
            ),
          ),
        );
      }
      return false;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(zh: '无法打开浏览器', en: 'Unable to open browser'),
          ),
        ),
      );
    }
    return launched;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.65);
    final accent = MemoFlowPalette.primary;
    final border = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final shadow = Colors.black.withValues(alpha: 0.12);
    final useDebugAnnouncement = kDebugMode &&
        config.debugAnnouncementSource == DebugAnnouncementSource.debugAnnouncement;
    final activeAnnouncement = useDebugAnnouncement
        ? (config.debugAnnouncement ?? config.announcement)
        : config.announcement;
    final donors = config.donors;
    final newDonors = activeAnnouncement.newDonorsFrom(donors);
    final newDonorLabels = newDonors
        .map((donor) => donor.name.trim().isNotEmpty ? donor.name.trim() : donor.id.trim())
        .where((name) => name.isNotEmpty)
        .map((name) => '@$name')
        .toList(growable: false);
    final version = currentVersion.trim();
    final latestVersion = config.versionInfo.latestVersion.trim();
    final targetVersion = latestVersion.isEmpty ? version : latestVersion;
    final rawTitle = activeAnnouncement.title.trim();
    final fallbackTitle = context.tr(zh: '版本公告', en: 'Release Notes');
    final titleBase = rawTitle.isEmpty ? fallbackTitle : rawTitle;
    final title = targetVersion.isEmpty ? titleBase : '$titleBase v$targetVersion';
    final releaseEntry = useDebugAnnouncement ? null : config.releaseNoteForVersion(targetVersion);
    final announcementItems = useDebugAnnouncement
        ? activeAnnouncement
            .contentsForLanguageCode(Localizations.localeOf(context).languageCode)
            .map(
              (line) => VersionAnnouncementItem(
                category: ReleaseNoteCategory.feature,
                detailZh: line,
                detailEn: line,
              ),
            )
            .toList(growable: false)
        : buildVersionAnnouncementItems(releaseEntry);
    final showUpdateAction = _compareVersionTriplets(config.versionInfo.latestVersion, version) > 0;
    final isForce = config.versionInfo.isForce && showUpdateAction;

    Widget buildAnnouncementItems() {
      if (announcementItems.isEmpty) {
        return Text(
          context.tr(zh: '暂无更新日志', en: 'No release notes yet'),
          style: TextStyle(fontSize: 13.5, height: 1.35, color: textMuted),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < announcementItems.length; i++) ...[
            _ReleaseNoteRow(
              item: announcementItems[i],
              textMain: textMain,
              textMuted: textMuted,
              isDark: isDark,
            ),
            if (i != announcementItems.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }

    Widget buildDonorSection() {
      if (donors.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          Divider(height: 1, color: border.withValues(alpha: 0.7)),
          if (newDonorLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              context.tr(
                zh: '本次更新特别鸣谢：${newDonorLabels.join(' ')}',
                en: 'Special thanks: ${newDonorLabels.join(' ')}',
              ),
              style: TextStyle(fontSize: 12.5, height: 1.4, color: textMuted),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DonorsWallScreen()),
                );
              },
              child: Text(
                context.tr(zh: '查看完整致谢名单', en: 'View full contributors'),
                style: TextStyle(
                  fontSize: 12,
                  color: accent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: PopScope(
        canPop: false,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight * 0.88;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 332, maxHeight: maxHeight),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            blurRadius: 26,
                            offset: const Offset(0, 14),
                            color: shadow,
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rocket_launch_rounded, size: 48, color: accent),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildAnnouncementItems(),
                                buildDonorSection(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (showUpdateAction)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                final launched = await _launchDownload(context, config.versionInfo.downloadUrl);
                                if (!launched || isForce) return;
                                if (context.mounted) {
                                  Navigator.of(context).pop(AnnouncementAction.update);
                                }
                              },
                              child: Text(
                                context.tr(zh: '立即获取新版本', en: 'Get the new version'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (isForce)
                          TextButton(
                            onPressed: () {
                              SystemNavigator.pop();
                            },
                            child: Text(
                              context.tr(zh: '退出应用', en: 'Exit app'),
                              style: TextStyle(fontSize: 12.5, color: textMuted),
                            ),
                          )
                        else
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(AnnouncementAction.later),
                            child: Text(
                              context.tr(zh: '稍后再说', en: 'Maybe later'),
                              style: TextStyle(fontSize: 12.5, color: textMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReleaseNoteRow extends StatelessWidget {
  const _ReleaseNoteRow({
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
    final highlight = item.category.tone(isDark: isDark);
    final detail = context.tr(zh: item.detailZh, en: item.detailEn);

    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 13.5, height: 1.35, color: textMain),
        children: [
          TextSpan(
            text: title,
            style: TextStyle(fontWeight: FontWeight.w700, color: highlight),
          ),
          TextSpan(text: detail, style: TextStyle(color: textMuted)),
        ],
      ),
    );
  }
}

List<int> _parseVersionTriplet(String version) {
  if (version.trim().isEmpty) return const [0, 0, 0];
  final trimmed = version.split(RegExp(r'[-+]')).first;
  final parts = trimmed.split('.');
  final values = <int>[0, 0, 0];
  for (var i = 0; i < 3; i++) {
    if (i >= parts.length) break;
    final match = RegExp(r'\d+').firstMatch(parts[i]);
    if (match == null) continue;
    values[i] = int.tryParse(match.group(0) ?? '') ?? 0;
  }
  return values;
}

int _compareVersionTriplets(String a, String b) {
  final left = _parseVersionTriplet(a);
  final right = _parseVersionTriplet(b);
  for (var i = 0; i < 3; i++) {
    final diff = left[i] - right[i];
    if (diff != 0) return diff;
  }
  return 0;
}
