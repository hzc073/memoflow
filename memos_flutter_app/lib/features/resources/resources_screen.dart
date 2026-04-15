import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/drawer_navigation.dart';
import '../../core/desktop_window_controls.dart';
import '../../core/platform_layout.dart';
import '../../core/top_toast.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../state/system/database_provider.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/system/session_provider.dart';
import '../home/app_drawer.dart';
import '../home/app_drawer_destination_builder.dart';
import '../home/app_drawer_menu_button.dart';
import '../home/home_navigation_host.dart';
import '../memos/attachment_video_screen.dart';
import '../memos/memo_detail_screen.dart';
import '../memos/memos_list_screen.dart';
import '../memos/memo_video_grid.dart';
import '../notifications/notifications_screen.dart';
import '../../i18n/strings.g.dart';

class _AttachmentSection {
  const _AttachmentSection({required this.kind, required this.entries});

  final AttachmentCategory kind;
  final List<ResourceEntry> entries;
}

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({
    super.key,
    this.presentation = HomeScreenPresentation.standalone,
    this.embeddedNavigationHost,
  });

  @visibleForTesting
  static void Function(String routeName)? debugRouteRequestOverride;

  final HomeScreenPresentation presentation;
  final HomeEmbeddedNavigationHost? embeddedNavigationHost;

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  final Set<AttachmentCategory> _collapsedKinds = <AttachmentCategory>{};

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

  String? _resolveRemoteUrl(
    Uri? baseUrl,
    Attachment attachment, {
    required bool thumbnail,
  }) {
    final link = attachment.externalLink.trim();
    if (link.isNotEmpty && !link.startsWith('file://')) {
      final isRelative = !isAbsoluteUrl(link);
      final resolved = resolveMaybeRelativeUrl(baseUrl, link);
      if (!thumbnail || !isRelative) return resolved;
      return appendThumbnailParam(resolved);
    }
    if (baseUrl == null) return null;
    final url = joinBaseUrl(
      baseUrl,
      'file/${attachment.name}/${attachment.filename}',
    );
    return thumbnail ? appendThumbnailParam(url) : url;
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

      final external = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
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
    showTopToast(context, context.t.strings.legacy.msg_downloading);

    try {
      final rootDir = await _resolveDownloadDirectory();
      if (!context.mounted) return;
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
            SnackBar(
              content: Text(
                context.t.strings.legacy.msg_no_download_url_available,
              ),
            ),
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
      showTopToast(
        context,
        context.t.strings.legacy.msg_saved(targetPath: targetPath),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_download_failed(e: e)),
        ),
      );
    }
  }

  void _openPreview(
    BuildContext context,
    Attachment attachment, {
    required Uri? baseUrl,
    required String? authHeader,
    required bool rebaseAbsoluteFileUrlForV024,
    required bool attachAuthForSameOriginAbsolute,
  }) {
    final isImage = attachment.isImage;
    final isAudio = attachment.isAudio;
    final isVideo = attachment.isVideo;
    final localFile = _localAttachmentFile(attachment);

    if (isImage) {
      final debugRouteRequestOverride =
          ResourcesScreen.debugRouteRequestOverride;
      if (debugRouteRequestOverride != null) {
        debugRouteRequestOverride('resources/image-preview');
        return;
      }

      final url = _resolveRemoteUrl(baseUrl, attachment, thumbnail: false);
      if (localFile == null && (url == null || url.isEmpty)) {
        _showUnsupportedPreview(context);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'resources/image-preview'),
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

    if (isVideo) {
      final debugRouteRequestOverride =
          ResourcesScreen.debugRouteRequestOverride;
      if (debugRouteRequestOverride != null) {
        debugRouteRequestOverride('resources/video-preview');
        return;
      }

      final entry = memoVideoEntryFromAttachment(
        attachment,
        baseUrl,
        authHeader,
        rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
        attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
      );
      if (entry == null ||
          (entry.localFile == null && (entry.videoUrl ?? '').isEmpty)) {
        _showUnsupportedPreview(context);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'resources/video-preview'),
          builder: (_) => AttachmentVideoScreen(
            title: entry.title,
            localFile: entry.localFile,
            videoUrl: entry.videoUrl,
            thumbnailUrl: entry.thumbnailUrl,
            headers: entry.headers,
            cacheId: entry.id,
            cacheSize: entry.size,
          ),
        ),
      );
      return;
    }

    if (isAudio) {
      final debugRouteRequestOverride =
          ResourcesScreen.debugRouteRequestOverride;
      if (debugRouteRequestOverride != null) {
        debugRouteRequestOverride('resources/audio-preview');
        return;
      }

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
    showTopToast(
      context,
      context.t.strings.legacy.msg_preview_not_supported_type,
    );
  }

  void _backToAllMemos(BuildContext context) {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleBackToPrimaryDestination(context);
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

  void _navigate(BuildContext context, AppDrawerDestination dest) {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleDrawerDestination(context, dest);
      return;
    }
    closeDrawerThenPushReplacement(
      context,
      buildDrawerDestinationScreen(context: context, destination: dest),
    );
  }

  void _openTag(BuildContext context, String tag) {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleDrawerTag(context, tag);
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
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleOpenNotifications(context);
      return;
    }
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  String _displayName(Attachment attachment) {
    return attachment.displayName;
  }

  AttachmentCategory _classifyAttachment(Attachment attachment) {
    return attachment.searchCategory;
  }

  int _compareEntries(ResourceEntry a, ResourceEntry b) {
    final byTime = b.memoUpdateTime.compareTo(a.memoUpdateTime);
    if (byTime != 0) return byTime;

    final byName = _displayName(
      a.attachment,
    ).toLowerCase().compareTo(_displayName(b.attachment).toLowerCase());
    if (byName != 0) return byName;

    final byMemoUid = a.memoUid.compareTo(b.memoUid);
    if (byMemoUid != 0) return byMemoUid;
    return a.attachment.uid.compareTo(b.attachment.uid);
  }

  List<_AttachmentSection> _groupEntries(List<ResourceEntry> entries) {
    final grouped = <AttachmentCategory, List<ResourceEntry>>{
      for (final kind in AttachmentCategory.values) kind: <ResourceEntry>[],
    };
    for (final entry in entries) {
      grouped[_classifyAttachment(entry.attachment)]!.add(entry);
    }

    final sections = <_AttachmentSection>[];
    for (final kind in AttachmentCategory.values) {
      final items = grouped[kind]!;
      items.sort(_compareEntries);
      if (items.isEmpty) continue;
      sections.add(_AttachmentSection(kind: kind, entries: items));
    }
    return sections;
  }

  String _kindLabel(BuildContext context, AttachmentCategory kind) {
    return switch (kind) {
      AttachmentCategory.image => context.t.strings.legacy.msg_image,
      AttachmentCategory.audio => context.t.strings.legacy.msg_audio,
      AttachmentCategory.document => context.t.strings.legacy.msg_document,
      AttachmentCategory.other => context.t.strings.legacy.msg_other,
    };
  }

  IconData _kindIcon(AttachmentCategory kind) {
    return switch (kind) {
      AttachmentCategory.image => Icons.image_outlined,
      AttachmentCategory.audio => Icons.graphic_eq_rounded,
      AttachmentCategory.document => Icons.description_outlined,
      AttachmentCategory.other => Icons.category_outlined,
    };
  }

  String _fileBadgeLabel(BuildContext context, Attachment attachment) {
    final extension = p
        .extension(_displayName(attachment))
        .replaceFirst('.', '');
    if (extension.isNotEmpty) return extension.toUpperCase();
    return context.t.strings.legacy.msg_file;
  }

  Future<void> _openSourceMemo(BuildContext context, String memoUid) async {
    final debugRouteRequestOverride = ResourcesScreen.debugRouteRequestOverride;
    if (debugRouteRequestOverride != null) {
      debugRouteRequestOverride('resources/open-memo');
      return;
    }

    final row = await ref.read(databaseProvider).getMemoByUid(memoUid);
    if (row == null || !context.mounted) return;
    final memo = LocalMemo.fromDb(row);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'resources/open-memo'),
        builder: (_) => MemoDetailScreen(initialMemo: memo),
      ),
    );
  }

  bool _isSectionCollapsed(AttachmentCategory kind) {
    return _collapsedKinds.contains(kind);
  }

  void _toggleSection(AttachmentCategory kind) {
    setState(() {
      if (!_collapsedKinds.add(kind)) {
        _collapsedKinds.remove(kind);
      }
    });
  }

  Widget _buildSectionHeader(BuildContext context, _AttachmentSection section) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCollapsed = _isSectionCollapsed(section.kind);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('resources-section-title-${section.kind.name}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => _toggleSection(section.kind),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Row(
              children: [
                Icon(
                  _kindIcon(section.kind),
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_kindLabel(context, section.kind)} · ${section.entries.length}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  isCollapsed
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardPreview(
    BuildContext context, {
    required Attachment attachment,
    required AttachmentCategory kind,
    required File? localFile,
    required String? thumbnailUrl,
    required String? authHeader,
    required MemoVideoEntry? videoEntry,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isVideo = attachment.isVideo;
    final placeholder = Container(
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_kindIcon(kind), size: 34, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          if (!attachment.isImage && !attachment.isAudio && !isVideo)
            Text(
              _fileBadgeLabel(context, attachment),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );

    final Widget child = switch (kind) {
      AttachmentCategory.image when localFile != null => Image.file(
        localFile,
        fit: BoxFit.cover,
      ),
      AttachmentCategory.image when thumbnailUrl != null => CachedNetworkImage(
        imageUrl: thumbnailUrl,
        httpHeaders: authHeader == null ? null : {'Authorization': authHeader},
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => placeholder,
        placeholder: (context, url) => placeholder,
      ),
      AttachmentCategory.other when isVideo && videoEntry != null =>
        AttachmentVideoThumbnail(
          entry: videoEntry,
          borderRadius: 12,
          showPlayIcon: true,
        ),
      _ => placeholder,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(height: 82, width: double.infinity, child: child),
    );
  }

  Widget _buildAttachmentCard(
    BuildContext context, {
    required ResourceEntry entry,
    required Uri? baseUrl,
    required String? authHeader,
    required bool rebaseAbsoluteFileUrlForV024,
    required bool attachAuthForSameOriginAbsolute,
    required DateFormat dateFmt,
  }) {
    final attachment = entry.attachment;
    final kind = _classifyAttachment(attachment);
    final isVideo = attachment.isVideo;
    final displayName = _displayName(attachment);
    final localFile = _localAttachmentFile(attachment);
    final thumbnailUrl = _resolveRemoteUrl(
      baseUrl,
      attachment,
      thumbnail: true,
    );
    final remoteUrl = _resolveRemoteUrl(baseUrl, attachment, thumbnail: false);
    final videoEntry = isVideo
        ? memoVideoEntryFromAttachment(
            attachment,
            baseUrl,
            authHeader,
            rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
            attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
          )
        : null;
    final hasVideoSource =
        videoEntry != null &&
        (videoEntry.localFile != null ||
            (videoEntry.videoUrl ?? '').isNotEmpty);

    final hasDebugRouteOverride =
        ResourcesScreen.debugRouteRequestOverride != null;
    final canPreview =
        switch (kind) {
          AttachmentCategory.image ||
          AttachmentCategory.audio => localFile != null || remoteUrl != null,
          AttachmentCategory.document => false,
          AttachmentCategory.other =>
            isVideo &&
                (localFile != null || remoteUrl != null || hasVideoSource),
        } ||
        (hasDebugRouteOverride &&
            (kind == AttachmentCategory.image ||
                kind == AttachmentCategory.audio ||
                isVideo));
    final canDownload = localFile != null || remoteUrl != null;
    final colorScheme = Theme.of(context).colorScheme;
    final actionStyle = IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      foregroundColor: colorScheme.primary,
      padding: EdgeInsets.zero,
      minimumSize: const Size(28, 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Card(
      key: ValueKey('resources-card-${entry.memoUid}-${attachment.uid}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('resources-card-tap-${entry.memoUid}-${attachment.uid}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (canPreview) {
            _openPreview(
              context,
              attachment,
              baseUrl: baseUrl,
              authHeader: authHeader,
              rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
              attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
            );
            return;
          }
          _openSourceMemo(context, entry.memoUid);
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KeyedSubtree(
                key: ValueKey(
                  'resources-card-preview-${entry.memoUid}-${attachment.uid}',
                ),
                child: _buildCardPreview(
                  context,
                  attachment: attachment,
                  kind: kind,
                  localFile: localFile,
                  thumbnailUrl: thumbnailUrl,
                  authHeader: authHeader,
                  videoEntry: videoEntry,
                ),
              ),
              const SizedBox(height: 10),
              Tooltip(
                message: displayName,
                child: Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    _kindIcon(kind),
                    size: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _kindLabel(context, kind),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dateFmt.format(entry.memoUpdateTime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              Row(
                children: [
                  const Spacer(),
                  Tooltip(
                    message: context.t.strings.legacy.msg_open_memo,
                    child: IconButton(
                      key: ValueKey(
                        'resources-open-memo-${entry.memoUid}-${attachment.uid}',
                      ),
                      style: actionStyle,
                      onPressed: () => _openSourceMemo(context, entry.memoUid),
                      icon: const Icon(Icons.note_alt_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: context.t.strings.legacy.msg_download,
                    child: IconButton(
                      key: ValueKey(
                        'resources-download-${entry.memoUid}-${attachment.uid}',
                      ),
                      style: actionStyle,
                      onPressed: canDownload
                          ? () => _downloadAttachment(
                              context,
                              attachment,
                              baseUrl,
                              authHeader,
                            )
                          : null,
                      icon: const Icon(Icons.download_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final sessionController = ref.read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final rebaseAbsoluteFileUrlForV024 = isServerVersion024(serverVersion);
    final attachAuthForSameOriginAbsolute = isServerVersion021(serverVersion);
    final authHeader = (account?.personalAccessToken ?? '').isEmpty
        ? null
        : 'Bearer ${account!.personalAccessToken}';

    final entriesAsync = ref.watch(resourcesProvider);
    final dateFmt = DateFormat('yyyy-MM-dd');
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useDesktopSidePane = shouldUseDesktopSidePaneLayout(screenWidth);
    final enableWindowsDragToMove = Platform.isWindows;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerPanel = AppDrawer(
      selected: AppDrawerDestination.resources,
      onSelect: (d) => _navigate(context, d),
      onSelectTag: (t) => _openTag(context, t),
      onOpenNotifications: () => _openNotifications(context),
      embedded: useDesktopSidePane,
    );

    final shouldInterceptPop =
        widget.presentation != HomeScreenPresentation.embeddedBottomNav;

    return PopScope(
      canPop: !shouldInterceptPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !shouldInterceptPop) return;
        _backToAllMemos(context);
      },
      child: Scaffold(
        drawer: useDesktopSidePane ? null : drawerPanel,
        drawerEnableOpenDragGesture:
            widget.presentation != HomeScreenPresentation.embeddedBottomNav,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          toolbarHeight: 46,
          leading: useDesktopSidePane
              ? null
              : AppDrawerMenuButton(
                  tooltip: context.t.strings.legacy.msg_toggle_sidebar,
                  iconColor: colorScheme.onSurface,
                  badgeBorderColor: Theme.of(context).scaffoldBackgroundColor,
                ),
          flexibleSpace: enableWindowsDragToMove
              ? const DragToMoveArea(child: SizedBox.expand())
              : null,
          title: IgnorePointer(
            ignoring: enableWindowsDragToMove,
            child: Text(
              context.t.strings.legacy.msg_attachments,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          actions: [if (enableWindowsDragToMove) const DesktopWindowControls()],
        ),
        body: (() {
          final pageBody = entriesAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return Center(
                  child: Text(context.t.strings.legacy.msg_no_attachments),
                );
              }

              final sections = _groupEntries(entries);
              return Scrollbar(
                child: CustomScrollView(
                  slivers: [
                    for (final section in sections) ...[
                      SliverToBoxAdapter(
                        child: _buildSectionHeader(context, section),
                      ),
                      if (!_isSectionCollapsed(section.kind))
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 220,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 214,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              return _buildAttachmentCard(
                                context,
                                entry: section.entries[index],
                                baseUrl: baseUrl,
                                authHeader: authHeader,
                                rebaseAbsoluteFileUrlForV024:
                                    rebaseAbsoluteFileUrlForV024,
                                attachAuthForSameOriginAbsolute:
                                    attachAuthForSameOriginAbsolute,
                                dateFmt: dateFmt,
                              );
                            }, childCount: section.entries.length),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(context.t.strings.legacy.msg_failed_load_4(e: e)),
            ),
          );
          if (!useDesktopSidePane) {
            return pageBody;
          }

          final desktopContent = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: kMemoFlowDesktopContentMaxWidth,
                ),
                child: pageBody,
              ),
            ),
          );

          return Row(
            children: [
              SizedBox(width: kMemoFlowDesktopDrawerWidth, child: drawerPanel),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              Expanded(child: desktopContent),
            ],
          );
        })(),
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
    final enableWindowsDragToMove = Platform.isWindows;
    final child = localFile != null
        ? Image.file(localFile!, fit: BoxFit.contain)
        : CachedNetworkImage(
            imageUrl: imageUrl ?? '',
            httpHeaders: authHeader == null
                ? null
                : {'Authorization': authHeader!},
            fit: BoxFit.contain,
            placeholder: (context, _) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image),
          );

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: enableWindowsDragToMove
            ? const DragToMoveArea(child: SizedBox.expand())
            : null,
        title: IgnorePointer(
          ignoring: enableWindowsDragToMove,
          child: Text(title),
        ),
      ),
      body: SafeArea(
        child: InteractiveViewer(child: Center(child: child)),
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
          headers: widget.authHeader == null
              ? null
              : {'Authorization': widget.authHeader!},
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
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
                context.t.strings.legacy.msg_failed_load(
                  error: _error ?? context.t.strings.legacy.msg_request_failed,
                ),
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
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: textMain,
                        ),
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
