import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_localization.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/session_provider.dart';
import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../home/app_drawer.dart';
import '../memos/memo_detail_screen.dart';
import '../memos/memos_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import '../sync/sync_queue_screen.dart';

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

  String? _resolveRemoteUrl(Uri? baseUrl, Attachment attachment, {required bool thumbnail}) {
    final link = attachment.externalLink.trim();
    if (link.isNotEmpty && !link.startsWith('file://')) {
      if (link.startsWith('http://') || link.startsWith('https://')) return link;
      if (baseUrl == null) return null;
      return joinBaseUrl(baseUrl, link);
    }
    if (baseUrl == null) return null;
    final url = joinBaseUrl(baseUrl, 'file/${attachment.name}/${attachment.filename}');
    return thumbnail ? '$url?thumbnail=true' : url;
  }

  String _sanitizeFilename(String filename) {
    final trimmed = filename.trim();
    if (trimmed.isEmpty) return 'attachment';
    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _dedupePath(String dirPath, String filename) {
    final base = p.basenameWithoutExtension(filename);
    final ext = p.extension(filename);
    var candidate = p.join(dirPath, filename);
    var index = 1;
    while (File(candidate).existsSync()) {
      candidate = p.join(dirPath, '$base ($index)$ext');
      index++;
    }
    return candidate;
  }

  Future<Directory?> _tryGetDownloadsDirectory() async {
    try {
      return await getDownloadsDirectory();
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _resolveDownloadDirectory() async {
    if (Platform.isAndroid) {
      final candidates = <Directory>[
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Downloads'),
      ];
      for (final dir in candidates) {
        if (await dir.exists()) return dir;
      }

      final external = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (external != null && external.isNotEmpty) return external.first;

      final fallback = await getExternalStorageDirectory();
      if (fallback != null) return fallback;
    }

    final downloads = await _tryGetDownloadsDirectory();
    if (downloads != null) return downloads;
    return getApplicationDocumentsDirectory();
  }

  Future<void> _downloadAttachment(
    BuildContext context,
    Attachment attachment,
    Uri? baseUrl,
    String? authHeader,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final localFile = _localAttachmentFile(attachment);

    final rawName = attachment.filename.isNotEmpty
        ? attachment.filename
        : (attachment.uid.isNotEmpty ? attachment.uid : attachment.name);
    final safeName = _sanitizeFilename(rawName);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(context.tr(zh: '正在下载', en: 'Downloading...'))),
    );

    try {
      final rootDir = await _resolveDownloadDirectory();
      final outDir = Directory(p.join(rootDir.path, 'MemoFlow_attachments'));
      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }

      final targetPath = _dedupePath(outDir.path, safeName);

      if (localFile != null) {
        await localFile.copy(targetPath);
      } else {
        final url = _resolveRemoteUrl(baseUrl, attachment, thumbnail: false);
        if (url == null || url.isEmpty) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(content: Text(context.tr(zh: '无法获取下载链接', en: 'No download URL available'))),
          );
          return;
        }
        final dio = Dio();
        await dio.download(
          url,
          targetPath,
          options: Options(
            headers: authHeader == null ? null : {'Authorization': authHeader},
          ),
        );
      }

      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr(zh: '已保存到: $targetPath', en: 'Saved to: $targetPath'))),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr(zh: '下载失败: $e', en: 'Download failed: $e'))),
      );
    }
  }

  void _openPreview(
    BuildContext context,
    Attachment attachment, {
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    final isImage = attachment.type.startsWith('image/');
    final isAudio = attachment.type.startsWith('audio');
    final localFile = _localAttachmentFile(attachment);

    if (isImage) {
      final url = _resolveRemoteUrl(baseUrl, attachment, thumbnail: false);
      if (localFile == null && (url == null || url.isEmpty)) {
        _showUnsupportedPreview(context);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ImageViewerScreen(
            title: attachment.filename,
            localFile: localFile,
            imageUrl: url,
            authHeader: authHeader,
          ),
        ),
      );
      return;
    }

    if (isAudio) {
      final url = _resolveRemoteUrl(baseUrl, attachment, thumbnail: false);
      if (localFile == null && (url == null || url.isEmpty)) {
        _showUnsupportedPreview(context);
        return;
      }
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AudioPreviewSheet(
          title: attachment.filename,
          localFile: localFile,
          audioUrl: url,
          authHeader: authHeader,
        ),
      );
      return;
    }

    _showUnsupportedPreview(context);
  }

  void _showUnsupportedPreview(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(zh: '暂不支持该类型预览', en: 'Preview not supported for this type'))),
    );
  }

  void _backToAllMemos(BuildContext context) {
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

  void _navigate(BuildContext context, AppDrawerDestination dest) {
    context.safePop();
    final route = switch (dest) {
      AppDrawerDestination.memos =>
        const MemosListScreen(title: 'MemoFlow', state: 'NORMAL', showDrawer: true, enableCompose: true),
      AppDrawerDestination.syncQueue => const SyncQueueScreen(),
      AppDrawerDestination.explore => const ExploreScreen(),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => MemosListScreen(
          title: context.tr(zh: '\u5f52\u6863', en: 'Archive'),
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

                    final displayName = a.filename.trim().isNotEmpty
                        ? a.filename
                        : (a.uid.isNotEmpty ? a.uid : a.name);
                    final localFile = _localAttachmentFile(a);
                    final thumbnailUrl = _resolveRemoteUrl(baseUrl, a, thumbnail: true);
                    final remoteUrl = _resolveRemoteUrl(baseUrl, a, thumbnail: false);
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
                        : isImage && thumbnailUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: thumbnailUrl,
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

                    final canPreview = (isImage || isAudio) && (localFile != null || remoteUrl != null);
                    final canDownload = localFile != null || remoteUrl != null;

                    return ListTile(
                      leading: leading,
                      title: Text(displayName),
                      subtitle: Text('${a.type} · ${dateFmt.format(entry.memoUpdateTime)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: context.tr(zh: '预览', en: 'Preview'),
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: canPreview
                                ? () => _openPreview(
                                      context,
                                      a,
                                      baseUrl: baseUrl,
                                      authHeader: authHeader,
                                    )
                                : null,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                          IconButton(
                            tooltip: context.tr(zh: '下载', en: 'Download'),
                            icon: const Icon(Icons.download),
                            onPressed: canDownload ? () => _downloadAttachment(context, a, baseUrl, authHeader) : null,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                        ],
                      ),
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

class _ImageViewerScreen extends StatelessWidget {
  const _ImageViewerScreen({
    required this.title,
    this.localFile,
    this.imageUrl,
    this.authHeader,
  });

  final String title;
  final File? localFile;
  final String? imageUrl;
  final String? authHeader;

  @override
  Widget build(BuildContext context) {
    final child = localFile != null
        ? Image.file(localFile!, fit: BoxFit.contain)
        : CachedNetworkImage(
            imageUrl: imageUrl ?? '',
            httpHeaders: authHeader == null ? null : {'Authorization': authHeader!},
            fit: BoxFit.contain,
            placeholder: (context, _) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
          );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: InteractiveViewer(
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _AudioPreviewSheet extends StatefulWidget {
  const _AudioPreviewSheet({
    required this.title,
    required this.localFile,
    required this.audioUrl,
    required this.authHeader,
  });

  final String title;
  final File? localFile;
  final String? audioUrl;
  final String? authHeader;

  @override
  State<_AudioPreviewSheet> createState() => _AudioPreviewSheetState();
}

class _AudioPreviewSheetState extends State<_AudioPreviewSheet> {
  final _player = AudioPlayer();
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      if (widget.localFile != null) {
        await _player.setFilePath(widget.localFile!.path);
      } else if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
        await _player.setUrl(
          widget.audioUrl!,
          headers: widget.authHeader == null ? null : {'Authorization': widget.authHeader!},
        );
      } else {
        throw StateError('No audio source available');
      }
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF181818) : Colors.white;
    final textMain = isDark ? Colors.white : Colors.black87;
    final textMuted = textMain.withValues(alpha: 0.6);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textMuted),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                context.tr(zh: '加载失败: $_error', en: 'Failed to load: $_error'),
                style: TextStyle(color: textMuted),
              )
            else if (!_ready)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, _) {
                  final playing = _player.playing;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: textMain),
                        onPressed: () async {
                          if (playing) {
                            await _player.pause();
                          } else {
                            await _player.play();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (context, positionSnap) {
                          final position = positionSnap.data ?? Duration.zero;
                          final duration = _player.duration ?? Duration.zero;
                          return Text(
                            '${_formatDuration(position)} / ${_formatDuration(duration)}',
                            style: TextStyle(color: textMuted),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
