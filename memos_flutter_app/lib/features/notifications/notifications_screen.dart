import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../core/memo_relations.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';
import '../../data/models/notification_item.dart';
import '../../data/models/user.dart';
import '../../state/memos_providers.dart';
import '../../state/notifications_provider.dart';
import '../../state/session_provider.dart';
import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../home/app_drawer.dart';
import '../memos/memo_detail_screen.dart';
import '../memos/memos_list_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import '../sync/sync_queue_screen.dart';

enum _NotificationAction {
  markRead,
  delete,
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _backToAllMemos(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
          openDrawerOnStart: true,
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
    final notificationsAsync = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _backToAllMemos(context);
      },
      child: Scaffold(
        drawer: AppDrawer(
          selected: AppDrawerDestination.memos,
          onSelect: (d) => _navigate(context, d),
          onSelectTag: (t) => _openTag(context, t),
          onOpenNotifications: () => _openNotifications(context),
        ),
        appBar: AppBar(
          title: Text(context.tr(zh: '通知', en: 'Notifications')),
          leading: IconButton(
            tooltip: context.tr(zh: '返回', en: 'Back'),
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _backToAllMemos(context),
          ),
        ),
        body: notificationsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Center(child: Text(context.tr(zh: '暂无通知', en: 'No notifications')));
            }
            return RefreshIndicator(
              onRefresh: () async {
                final _ = await ref.refresh(notificationsProvider.future);
              },
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  if (item.type.toUpperCase() == 'MEMO_COMMENT') {
                    return _NotificationMemoCommentTile(
                      item: item,
                      dateFmt: dateFmt,
                      isDark: isDark,
                      textMain: textMain,
                      textMuted: textMuted,
                      onTap: () => _handleNotificationTap(context, ref, item),
                      onAction: (action) => _handleAction(context, ref, item, action),
                    );
                  }

                  final title = _typeLabel(context, item);
                  final meta = _metaText(context, item, dateFmt);

                  return ListTile(
                    leading: _NotificationBadge(
                      type: item.type,
                      isUnread: item.isUnread,
                      isDark: isDark,
                    ),
                    title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
                    subtitle: Text(meta, style: TextStyle(color: textMuted)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusPill(status: item.status, isUnread: item.isUnread, isDark: isDark),
                        const SizedBox(width: 6),
                        PopupMenuButton<_NotificationAction>(
                          tooltip: context.tr(zh: '操作', en: 'Actions'),
                          onSelected: (action) => _handleAction(context, ref, item, action),
                          itemBuilder: (context) => [
                            if (item.isUnread)
                              PopupMenuItem(
                                value: _NotificationAction.markRead,
                                child: Text(context.tr(zh: '标记已读', en: 'Mark as read')),
                              ),
                            PopupMenuItem(
                              value: _NotificationAction.delete,
                              child: Text(context.tr(zh: '删除', en: 'Delete')),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => _handleNotificationTap(context, ref, item),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(context.tr(zh: '加载失败：$e', en: 'Failed to load: $e'))),
        ),
      ),
    );
  }

  String _metaText(BuildContext context, AppNotification item, DateFormat dateFmt) {
    final parts = <String>[];
    if (item.sender.trim().isNotEmpty) {
      parts.add(context.tr(zh: '来自 ${_shortUserName(item.sender)}', en: 'From ${_shortUserName(item.sender)}'));
    }
    parts.add(dateFmt.format(item.createTime.toLocal()));
    return parts.join(' · ');
  }

  String _shortUserName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.contains('/')) return trimmed;
    return trimmed.split('/').last;
  }

  String _typeLabel(BuildContext context, AppNotification item) {
    final type = item.type.toUpperCase();
    return switch (type) {
      'MEMO_COMMENT' => context.tr(zh: '新评论', en: 'New comment'),
      'VERSION_UPDATE' => context.tr(zh: '版本更新', en: 'Version update'),
      _ => context.tr(zh: '通知', en: 'Notification'),
    };
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
  ) async {
    final type = item.type.toUpperCase();
    if (type != 'MEMO_COMMENT') {
      if (item.isUnread) {
        await _handleAction(context, ref, item, _NotificationAction.markRead);
      }
      return;
    }

    final activityId = item.activityId ?? 0;
    if (activityId <= 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(zh: '通知缺少内容', en: 'Notification content unavailable'),
          ),
        ),
      );
      return;
    }

    final api = ref.read(memosApiProvider);
    var dialogShown = false;
    try {
      if (context.mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        dialogShown = true;
      }

      final refs = await api.getMemoCommentActivityRefs(activityId: activityId);
      if (refs.commentMemoUid.isEmpty && refs.relatedMemoUid.isEmpty) {
        throw const FormatException('Missing memo reference');
      }

      Memo? targetMemo;
      if (refs.relatedMemoUid.isNotEmpty) {
        try {
          targetMemo = await api.getMemoCompat(memoUid: refs.relatedMemoUid);
        } catch (_) {}
      }
      if (targetMemo == null && refs.commentMemoUid.isNotEmpty) {
        try {
          targetMemo = await api.getMemoCompat(memoUid: refs.commentMemoUid);
        } catch (_) {}
      }

      if (targetMemo == null) {
        throw StateError('Unable to resolve memo');
      }

      if (dialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }
      if (!context.mounted) return;

      final localMemo = _toLocalMemo(targetMemo);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MemoDetailScreen(
            initialMemo: localMemo,
            readOnly: true,
            showEngagement: true,
          ),
        ),
      );

      if (item.isUnread) {
        try {
          await api.updateNotificationStatus(
            name: item.name,
            status: 'ARCHIVED',
            source: item.source,
          );
          ref.invalidate(notificationsProvider);
        } catch (_) {}
      }
    } catch (e) {
      if (dialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!context.mounted) return;
      if (_isMissingMemoError(e)) {
        if (item.isUnread) {
          try {
            await api.updateNotificationStatus(
              name: item.name,
              status: 'ARCHIVED',
              source: item.source,
            );
            ref.invalidate(notificationsProvider);
          } catch (_) {}
        }
        showTopToast(
          context,
          context.tr(
            zh: '通知对应的内容已被删除',
            en: 'The related memo was deleted',
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '打开通知失败：$e', en: 'Failed to open notification: $e'))),
      );
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
    _NotificationAction action,
  ) async {
    final api = ref.read(memosApiProvider);
    try {
      switch (action) {
        case _NotificationAction.markRead:
          await api.updateNotificationStatus(
            name: item.name,
            status: 'ARCHIVED',
            source: item.source,
          );
          break;
        case _NotificationAction.delete:
          await api.deleteNotification(
            name: item.name,
            source: item.source,
          );
          break;
      }
      ref.invalidate(notificationsProvider);
      if (!context.mounted) return;
      final message = action == _NotificationAction.markRead
          ? context.tr(zh: '已标记为已读', en: 'Marked as read')
          : context.tr(zh: '通知已删除', en: 'Notification deleted');
      showTopToast(context, message);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '操作失败：$e', en: 'Action failed: $e'))),
      );
    }
  }

  bool _isMissingMemoError(Object error) {
    if (error is! DioException) return false;
    final status = error.response?.statusCode ?? 0;
    if (status != 500) return false;
    final data = error.response?.data;
    String message = '';
    if (data is Map) {
      final raw = data['message'] ?? data['error'] ?? data['detail'];
      if (raw is String) message = raw;
    } else if (data is String) {
      message = data;
    }
    final lower = message.toLowerCase();
    return lower.contains('memo does not exist') || lower.contains('notfound');
  }

  LocalMemo _toLocalMemo(Memo memo) {
    return LocalMemo(
      uid: memo.uid,
      content: memo.content,
      contentFingerprint: memo.contentFingerprint,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTime: memo.createTime.toLocal(),
      updateTime: memo.updateTime.toLocal(),
      tags: memo.tags,
      attachments: memo.attachments,
      relationCount: countReferenceRelations(memoUid: memo.uid, relations: memo.relations),
      location: memo.location,
      syncState: SyncState.synced,
      lastError: null,
    );
  }
}

class _NotificationMemoCommentTile extends ConsumerStatefulWidget {
  const _NotificationMemoCommentTile({
    required this.item,
    required this.dateFmt,
    required this.isDark,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
    required this.onAction,
  });

  final AppNotification item;
  final DateFormat dateFmt;
  final bool isDark;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;
  final void Function(_NotificationAction action) onAction;

  @override
  ConsumerState<_NotificationMemoCommentTile> createState() => _NotificationMemoCommentTileState();
}

class _NotificationMemoCommentTileState extends ConsumerState<_NotificationMemoCommentTile> {
  User? _sender;
  Memo? _commentMemo;
  Memo? _relatedMemo;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(memosApiProvider);
    final item = widget.item;
    User? sender;
    Memo? commentMemo;
    Memo? relatedMemo;
    String? error;

    final senderName = item.sender.trim();
    if (senderName.isNotEmpty) {
      try {
        sender = await api.getUser(name: senderName);
      } catch (_) {}
    }

    final activityId = item.activityId ?? 0;
    if (activityId > 0) {
      try {
        final refs = await api.getMemoCommentActivityRefs(activityId: activityId);
        if (refs.commentMemoUid.isNotEmpty) {
          try {
            commentMemo = await api.getMemoCompat(memoUid: refs.commentMemoUid);
          } catch (_) {}
        }
        if (refs.relatedMemoUid.isNotEmpty) {
          try {
            relatedMemo = await api.getMemoCompat(memoUid: refs.relatedMemoUid);
          } catch (_) {}
        }
      } catch (e) {
        error = e.toString();
      }
    }

    if (!mounted) return;
    setState(() {
      _sender = sender;
      _commentMemo = commentMemo;
      _relatedMemo = relatedMemo;
      _loading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? null : 'Bearer $token';
    final isUnread = item.isUnread;

    final senderName = _creatorDisplayName(_sender, item.sender, context);
    final commentContent = _commentSnippet(_commentMemo?.content ?? '');
    final displayContent = commentContent.isNotEmpty
        ? commentContent
        : _commentSnippet(_relatedMemo?.content ?? '');
    final time = (_commentMemo?.createTime ?? item.createTime).toLocal();

    final previewMemo = _relatedMemo ?? _commentMemo;
    final previewAttachment = _firstImageAttachment(previewMemo?.attachments ?? const []);
    final previewText = _commentSnippet(previewMemo?.content ?? '');

    final bgColor = isUnread
        ? MemoFlowPalette.primary.withValues(alpha: 0.06)
        : (widget.isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight);

    return InkWell(
      onTap: widget.onTap,
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(
              creator: _sender,
              fallback: item.sender,
              textMuted: widget.textMuted,
              baseUrl: baseUrl,
              size: 40,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: widget.textMain,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayContent.isEmpty
                        ? context.tr(zh: '评论内容不可用', en: 'Comment unavailable')
                        : displayContent,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: widget.textMain.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.dateFmt.format(time),
                    style: TextStyle(fontSize: 12, color: widget.textMuted),
                  ),
                  if (_loading && _commentMemo == null && _relatedMemo == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        context.tr(zh: '加载中...', en: 'Loading...'),
                        style: TextStyle(fontSize: 11, color: widget.textMuted),
                      ),
                    ),
                  if (_error != null && _commentMemo == null && _relatedMemo == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        context.tr(zh: '加载失败', en: 'Load failed'),
                        style: TextStyle(fontSize: 11, color: widget.textMuted),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPreview(
                  previewAttachment: previewAttachment,
                  previewText: previewText,
                  baseUrl: baseUrl,
                  authHeader: authHeader,
                  isDark: widget.isDark,
                ),
                PopupMenuButton<_NotificationAction>(
                  tooltip: context.tr(zh: '操作', en: 'Actions'),
                  onSelected: widget.onAction,
                  itemBuilder: (context) => [
                    if (item.isUnread)
                      PopupMenuItem(
                        value: _NotificationAction.markRead,
                        child: Text(context.tr(zh: '标记已读', en: 'Mark as read')),
                      ),
                    PopupMenuItem(
                      value: _NotificationAction.delete,
                      child: Text(context.tr(zh: '删除', en: 'Delete')),
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

  Widget _buildPreview({
    required Attachment? previewAttachment,
    required String previewText,
    required Uri? baseUrl,
    required String? authHeader,
    required bool isDark,
  }) {
    const size = 56.0;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final bgColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);

    if (previewAttachment != null) {
      final url = _resolveAttachmentUrl(baseUrl, previewAttachment, thumbnail: true);
      if (url.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: url,
            httpHeaders: authHeader == null ? null : {'Authorization': authHeader},
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: size,
              height: size,
              color: bgColor,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => _textPreviewFallback(previewText, size, bgColor, borderColor),
          ),
        );
      }
    }

    return _textPreviewFallback(previewText, size, bgColor, borderColor);
  }

  Widget _textPreviewFallback(String text, double size, Color bgColor, Color borderColor) {
    final snippet = text.isEmpty ? '...' : text;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        snippet,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10, color: widget.textMain.withValues(alpha: 0.8)),
      ),
    );
  }

  static String _commentSnippet(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  Attachment? _firstImageAttachment(List<Attachment> attachments) {
    for (final attachment in attachments) {
      final type = attachment.type.trim().toLowerCase();
      if (type.startsWith('image')) return attachment;
    }
    return null;
  }

  String _resolveAttachmentUrl(Uri? baseUrl, Attachment attachment, {required bool thumbnail}) {
    final external = attachment.externalLink.trim();
    if (external.isNotEmpty) {
      final isRelative = !isAbsoluteUrl(external);
      final resolved = resolveMaybeRelativeUrl(baseUrl, external);
      return (thumbnail && isRelative) ? appendThumbnailParam(resolved) : resolved;
    }
    if (baseUrl == null) return '';
    final url = joinBaseUrl(baseUrl, 'file/${attachment.name}/${attachment.filename}');
    return thumbnail ? appendThumbnailParam(url) : url;
  }

  Widget _buildAvatar({
    required User? creator,
    required String fallback,
    required Color textMuted,
    required Uri? baseUrl,
    double size = 28,
  }) {
    final fallbackWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
      ),
      alignment: Alignment.center,
      child: Text(
        _creatorInitial(creator, fallback, context),
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: textMuted),
      ),
    );

    final avatarUrl = _resolveAvatarUrl(creator?.avatarUrl ?? '', baseUrl);
    if (avatarUrl.isEmpty) return fallbackWidget;
    if (avatarUrl.startsWith('data:')) {
      final bytes = tryDecodeDataUri(avatarUrl);
      if (bytes == null) return fallbackWidget;
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallbackWidget,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallbackWidget,
        errorWidget: (_, __, ___) => fallbackWidget,
      ),
    );
  }

  String _creatorDisplayName(User? creator, String fallback, BuildContext context) {
    final display = creator?.displayName.trim() ?? '';
    if (display.isNotEmpty) return display;
    final username = creator?.username.trim() ?? '';
    if (username.isNotEmpty) return username;
    final trimmed = fallback.trim();
    if (trimmed.startsWith('users/')) {
      return '${context.tr(zh: '用户', en: 'User')} ${trimmed.substring('users/'.length)}';
    }
    return trimmed.isEmpty ? context.tr(zh: '未知用户', en: 'Unknown') : trimmed;
  }

  String _creatorInitial(User? creator, String fallback, BuildContext context) {
    final display = _creatorDisplayName(creator, fallback, context);
    if (display.isEmpty) return '?';
    return display.characters.first.toUpperCase();
  }

  String _resolveAvatarUrl(String rawUrl, Uri? baseUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('data:')) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    if (baseUrl == null) return trimmed;
    return joinBaseUrl(baseUrl, trimmed);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.isUnread, required this.isDark});

  final String status;
  final bool isUnread;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final base = isUnread ? MemoFlowPalette.primary : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45);
    final label = isUnread
        ? context.tr(zh: '未读', en: 'Unread')
        : (status.isEmpty ? context.tr(zh: '已读', en: 'Read') : context.tr(zh: '已读', en: 'Read'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: base.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: base),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({
    required this.type,
    required this.isUnread,
    required this.isDark,
  });

  final String type;
  final bool isUnread;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final normalized = type.toUpperCase();
    final icon = switch (normalized) {
      'MEMO_COMMENT' => Icons.chat_bubble_outline,
      'VERSION_UPDATE' => Icons.system_update_alt,
      _ => Icons.notifications,
    };
    final color = isUnread ? MemoFlowPalette.primary : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: isUnread ? 0.18 : 0.12),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
