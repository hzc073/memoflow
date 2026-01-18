import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/session_provider.dart';
import '../about/about_screen.dart';
import '../home/app_drawer.dart';
import '../memos/memo_detail_screen.dart';
import '../memos/memos_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';

class ResourcesScreen extends ConsumerWidget {
  const ResourcesScreen({super.key});

  File? _localAttachmentFile(Attachment attachment) {
    final raw = attachment.externalLink.trim();
    if (!raw.startsWith('file://')) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final path = uri.toFilePath();
    if (path.trim().isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }

  void _backToAllMemos(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'memoflow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
      ),
      (route) => false,
    );
  }

  void _navigate(BuildContext context, AppDrawerDestination dest) {
    context.safePop();
    final route = switch (dest) {
      AppDrawerDestination.memos =>
        const MemosListScreen(title: 'memoflow', state: 'NORMAL', showDrawer: true, enableCompose: true),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => MemosListScreen(
          title: context.tr(zh: '回收站', en: 'Archive'),
          state: 'ARCHIVED',
          showDrawer: true,
        ),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => route));
  }

  void _openTag(BuildContext context, String tag) {
    context.safePop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MemosListScreen(
          title: '#$tag',
          state: 'NORMAL',
          tag: tag,
          showDrawer: true,
          enableCompose: true,
        ),
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    context.safePop();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final authHeader = (account?.personalAccessToken ?? '').isEmpty ? null : 'Bearer ${account!.personalAccessToken}';

    final entriesAsync = ref.watch(resourcesProvider);
    final dateFmt = DateFormat('yyyy-MM-dd');

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _backToAllMemos(context);
      },
      child: Scaffold(
        drawer: AppDrawer(
          selected: AppDrawerDestination.resources,
          onSelect: (d) => _navigate(context, d),
          onSelectTag: (t) => _openTag(context, t),
          onOpenNotifications: () => _openNotifications(context),
        ),
        appBar: AppBar(title: Text(context.tr(zh: '附件', en: 'Attachments'))),
        body: entriesAsync.when(
          data: (entries) => entries.isEmpty
              ? Center(child: Text(context.tr(zh: '暂无附件', en: 'No attachments')))
              : ListView.separated(
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final a = entry.attachment;
                    final isImage = a.type.startsWith('image/');
                    final isAudio = a.type.startsWith('audio');

                    final localFile = _localAttachmentFile(a);
                    final leading = isImage && localFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              localFile,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          )
                        : isImage && baseUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: a.externalLink.isNotEmpty
                                      ? a.externalLink
                                      : '${joinBaseUrl(baseUrl, 'file/${a.name}/${a.filename}')}?thumbnail=true',
                                  httpHeaders: authHeader == null ? null : {'Authorization': authHeader},
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(Icons.image),
                                  ),
                                ),
                              )
                            : Icon(isAudio ? Icons.mic : Icons.attach_file);

                    return ListTile(
                      leading: leading,
                      title: Text(a.filename),
                      subtitle: Text('${a.type} · ${dateFmt.format(entry.memoUpdateTime)}'),
                      onTap: () async {
                        final row = await ref.read(databaseProvider).getMemoByUid(entry.memoUid);
                        if (row == null) return;
                        final memo = LocalMemo.fromDb(row);
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => MemoDetailScreen(initialMemo: memo)),
                        );
                      },
                    );
                  },
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemCount: entries.length,
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(context.tr(zh: '加载失败：$e', en: 'Failed to load: $e'))),
        ),
      ),
    );
  }
}
